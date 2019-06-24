package Blacklists;
=encoding utf8

=head1 NAME

Blacklists

=head1 SYNOPSIS

    use Blacklists;

Initialize the Blacklists
    my $bls= Blacklists->new( {
        storage  => '/path/to/storage',
        lists    => { list config },
        severity => { severity config },
      }
    ) 

Check a domain
    my $res= $bls->check_domain( $domain );
Returns a hash in SIWECOS-Result-Format 

=head1 DESCRIPTION

BlacklistDB provides means to check for domains.

=head1 CONFIGURATION

The configuration is a hash of IDs to blacklistfile configurations.

=head1 METHODS

=cut

use strict;
use warnings;
use File::Basename;
use Carp;
use BlacklistReader;
use BinaryTreeFile;
use SiwecosResult;
use SiwecosTest;
use SiwecosTestDetail;
use Socket;

use Mojo::UserAgent;
use Mojo::JSON;
use Net::IDN::Encode qw(:all);

use Storable qw( nstore retrieve );

my $INDEXFILE= '.index';

=head2 new

(Class method) Returns a new instance of class Blacklists. The
attributes are described by a hash ref.

my $bls = Blacklists->new ({ attributes ... });

The following attributes are available:

=over 4

=item storage

Defines a path to the directory, where the Blacklists' data is stored.

my $bls = Blacklists->new ({ storage => '/path/to/blacklists', ... });

Each blacklist will be stored in this directory under its name.

An index file (".index") will be stored as well. 

=item lists

a reference to a hash of IDs to blacklist configurations
as expected by BlacklistReader.

=item severity

Define for each blacklist kind how much to reduce from 100%
 and which criticality to report when a domain was found.

my $bls = Blacklists->new ({
    ...
    severity => {
        PHISHING => { critical => 100 },
        SPAM => { warning => 50 },
    },
    ...
});

=cut

sub new {
    my($class, $attr)= @_;
    $class= ref($class) || $class;
    my $self= { %$attr, };
    bless $self, $class;
    $self->_initialize() or return undef;
    return $self;
}

sub _initialize {
    my($self)= @_;
    my $error= "";
    foreach my $required (qw( storage lists )) {
        next if defined $self->{$required};
        $error.= "$required not defined for blacklists.\n";
    }
    my $lists= $self->{lists};
    $self->{data}= {};
    PREPARE_LISTS:{ if ($lists) {
        if ('HASH' ne ref $lists) {
            $error.= "list is of wrong type.\n";
            last PREPARE_LISTS;
        }
        while (my($list, $config)= each %$lists) {
            my $blr= BlacklistReader->new($list, $config);
            next unless $blr;
            $self->{readers}{$list}= $blr;
            $self->{data}{$list}= {
                updated   => 0,
                bintree   => undef,
                kind      => $self->{readers}{$list}{config}{kind},
                reference => $self->{readers}{$list}{config}{reference},
            };
        }
    }}
    my $severity= $self->{severity};
    PREPARE_SEVERITY:{ if ($severity) {
        if ('HASH' ne ref $severity) {
            $error.= "severity is of wrong type.\n";
            last PREPARE_SEVERITY;
        }
        while (my($kind, $definition)= each %$severity) {
            if ('HASH' eq ref $definition) {
                my $scoretype= $definition->{scoreType};
                my $reduce= $definition->{reduce};
                $error.= "Missing scoretype for list kind $severity.\n"
                    unless $scoretype;
                $error.= "Unknown scoretype »$scoretype« for list kind $kind.\n"
                    unless $scoretype=~ /^(?:warning|critical)$/;
                $error.= "Missing reduce »$scoretype« for list kind $kind.\n"
                    unless $reduce;
                $error.= "Illegal reduce »$reduce« for list kind $kind.\n"
                    unless $reduce=~/^\d+$/ and $reduce >= 0 and $reduce <= 100; 
            } else {
                $error.= "Illegal severity definition for $kind.\n";
            }
        }
    }}
    my $storage= $self->{storage};
    my $index= undef;
    PREPARE_STORAGE:{ if ($storage) {
        $index= $self->{index}= "$storage/$INDEXFILE";
        if (not -r $index) {
            if (not nstore($self->{data}, $index)) {
                $error.= "Couldn't create $index.\n";
            }
            last PREPARE_STORAGE;
        }
        my $result= $self->_retrieve;
        if ($result and $result ne 1) {
            $error.= $result . "\n";
        }
    }}
    if ($error) {
        carp $error;
        return undef;
    }
    $self->{listtypes}= $self->_listtypes;
    return $self;
}

=head2 update

Update the blacklists and return an result hash listing all blacklists
which were updated, kept, dropped or failed to load.

=cut

sub update {
    my($self)= @_;
    my @dropped = ();
    # remove all loaded blacklists (data) which are no longer configured
    while (my($blacklist_id, $bldata)= each %{$self->{data}}) {
        if (not exists $self->{readers}{$blacklist_id}) {
            delete $self->{data}{$blacklist_id};
            push @dropped, $blacklist_id;
        }
    }
    # prepare all blacklists configured but not yet loaded
    foreach my $configured_blacklist_name (keys %{$self->{readers}}) {
        next if exists $self->{data}{$configured_blacklist_name};
        my $reader= $self->{readers}{$configured_blacklist_name};
        $self->{data}{$configured_blacklist_name}= {
            updated   => 0,
            bintree   => undef,
            kind      => $reader->{config}{kind},
            reference => $reader->{config}{reference},
            entries   => 0,
            status    => 'new',
        };
    }
    # Update/load all configured lists
    my $updated= 0;
    my $failed= 0;
    my $kept= 0;
    foreach my $blacklist_id (keys %{$self->{data}}) {
        my $reader= $self->{readers}{$blacklist_id};
        next unless $reader;
        if ($reader->{config}{domain}) {
            ++$updated if $reader->{config}{domain} ne ( $self->{data}{$blacklist_id}{domain} || '' ) ;
            $self->{data}{$blacklist_id}{status}= 'dns_lookup';
            $self->{data}{$blacklist_id}{domain}= $reader->{config}{domain};
            next;
        }
        if ($reader->{config}{ip}) {
            ++$updated if $reader->{config}{ip} ne ( $self->{data}{$blacklist_id}{ip} || '' ) ;
            $self->{data}{$blacklist_id}{status}= 'dns_lookup';
            $self->{data}{$blacklist_id}{ip}= $reader->{config}{ip};
            next;
        }
        my $bintree_file= $self->{storage} . '/' . $blacklist_id;
        my $last_modified= $self->{data}{$blacklist_id}{updated};
        # if the file is missing we load regardless
        $last_modified= 0 if not -r $bintree_file;
        my $updated_list= $reader->fetch($last_modified);
        if (not defined $updated_list) {
            carp "Could not update $blacklist_id";
            $self->{data}{$blacklist_id}{status}= 'failed';
            ++$failed;
            next;
        }
        if (not $updated_list) {
            $self->{data}{$blacklist_id}{status}= 'kept';
            ++$kept;
            next;
        }
        ++$updated;

        my @reverse_domains= sort map {scalar reverse} @{$updated_list->{domains}};
        my $bintree= BinaryTreeFile->new( $bintree_file, \@reverse_domains);
        if ($bintree) {
            $self->{data}{$blacklist_id}= {
                updated   => $updated_list->{updated},
                bintree   => $bintree,
                kind      => $reader->{config}{kind},
                reference => $reader->{config}{reference},
                entries   => scalar @reverse_domains,
                status    => 'updated',
            }
        } else {
            $self->{data}{$blacklist_id}{status}= 'save_error';
        }
    }
    # If anything was updated, store as temporary file
    if ($updated) {
        if (nstore($self->{data}, $self->{index}.$$)) {
            # when stored overwrite existing file
            if (not rename $self->{index}.$$, $self->{index}) {
                carp "Failed to save index file ".$self->{index};
            } 
        } else {
            carp "Failed to save temporary index file ".$self->{index}.$$;
        }
    }
    $self->{listtypes}= $self->_listtypes;
    return {
        updates => $updated,
        fails   => $failed,
        kept    => $kept,
        dropped => \@dropped,
    };
}

=head2 get_lists

Will return a reference to all blacklists

=cut

sub get_lists {
    my($self)= @_;
    return $self->{data};
}

=head2 status_string

Will return the current status of the blacklists

=cut

sub status_string {
    my($self)= @_;
    my $width= 0;
    my %liststatus;
    while (my($id, $info)= each %{$self->{data}}) {
        my $w= length $id;
        $width= $w if $w > $width;
        ++$liststatus{$info->{status} || 'missing' }{$id};
    }
    foreach (values %liststatus) {
        $_= [ sort keys %$_ ];
    }
    my $output= '';
    foreach my $status (qw( save_error failed dns_lookup kept updated )) {
        next unless $liststatus{$status};
        $output.= "Lists $status:\n";
        foreach my $id (@{$liststatus{$status}}) {
            if ($status eq 'dns_lookup') {
                $output.= sprintf "    %-${width}s\n",
                    $id;
            } else {
                my $file_missing= -r $self->{data}{$id}{bintree}->filename ? '' : ' file not found'; 
                $output.= sprintf "    %-${width}s (%s)%s\n",
                    $id,
                    Mojo::Date->new($self->{data}{$id}{updated})->to_datetime,
                    $file_missing;
            }
        }
    }
    return $output;
}

=head2 domain_check( $domain )

Requires a domain and will return a hash in SiwecosResult format.

Will check whether or not the domain or the domain with "www." prepended
is in any of the blacklists.

=cut

sub domain_check {
    my ($self, $domain)= @_;
    $self->_retrieve;
    my $tests= [];
    my $sResult= SiwecosResult->new({
        name => $ENV{SCANNER_NAME},
        version => $ENV{VERSION},
    });
    # clean domain
    for ($domain) {
        $_= lc $_;
        s#^https?://(?:www\.)?##;
        s#[:/].*$##;
    }
    # check domain
    my $matches= $self->_checkmatch($domain);

    # Each listtype (i.e. kind of backlist) becomes a new test
    foreach my $kind (@{$self->{listtypes}}) {
        # Prepare the test data
        my $test= SiwecosTest->new({
            name => $kind,
        });
        # and add it to the result
        $sResult->add_test($test);

        # Scoretype and reduce are test-dependent
        my $scoreType;
        my $reduce;
        # Check the values configured
        if (exists $self->{severity} and exists $self->{severity}->{$kind}) {
            $scoreType= $self->{severity}->{$kind}->{scoreType};
            $reduce= $self->{severity}->{$kind}->{reduce};
        }
        # otherwise use defaults
        $scoreType||= 'warning';
        $reduce= 100 unless defined $reduce;

        # Remember whether we got testdetails
        my $new_details;
        # Get the results for the domain
        my $result= $matches->{$kind};
        if ($result) {
            $new_details||= 1;
            foreach my $listname (sort keys %{$result}) {
                $test->add_testDetails($result->{$listname});
            }
        }
        # Calculate the test score for the test
        if ($new_details)  {
            $test->{score} = 100 - $reduce;
            $test->{scoreType} = $scoreType;
        } else {
            $test->{score} = 100;
            $test->{scoreType} = 'success';
        }
    }
    # Calculate the total_score
    $sResult->calc_score;
    return $sResult;
}

sub _checkmatch {
    my($self, $domain)= @_;
    my %tests;
    while (my($list, $bldata)= each %{$self->{data}}) {
        my $bl_provider;
        if (ref $bldata->{bintree}) {
            next unless $bldata->{bintree}->reverse_domain_match($domain);
            # Store the information as a SiwecosTestDetail
            $tests{uc $bldata->{kind}}{$list}= SiwecosTestDetail->new({
                translationStringId => 'DOMAIN_FOUND',
                placeholders => {
                    LISTNAME => $list,
                    LISTURL => $bldata->{reference},
                    DOMAIN => $domain,
                },
            });
        } elsif ($bl_provider= $bldata->{domain}) {
            my ($name,$aliases,$addrtype,$length,@addrs) = gethostbyname("$domain.$bl_provider");
            my %already_found;
            foreach my $addr (@addrs) {
                my $kind= $bldata->{kind}{$addr};
                next unless $kind;
                $kind= uc $kind;
                next if $already_found{$kind}++;
                $tests{$kind}{$list}= SiwecosTestDetail->new({
                    translationStringId => 'DOMAIN_FOUND',
                    placeholders => {
                        LISTNAME => $list,
                        LISTURL => $bldata->{reference},
                        DOMAIN => $domain,
                    },
                });
            }
        } elsif ($bl_provider= $bldata->{ip}) {
            my ($name,$aliases,$addrtype,$length,@addrs) = gethostbyname($domain);
            foreach my $my_addr (@addrs) {
                my $ip= inet_ntoa $my_addr;
                my $reverse_ip= join '.', reverse split /\./, $ip;
                my ($name,$aliases,$addrtype,$length,@addrs) = gethostbyname("$reverse_ip.$bl_provider");
                my %already_found;
                foreach my $addr (@addrs) {
                    my $kind= $bldata->{kind}{$addr};
                    next unless $kind;
                    $kind= uc $kind;
                    next if $already_found{$kind}++;
                    $tests{$kind}{$list}= SiwecosTestDetail->new({
                        translationStringId => 'IP_FOUND',
                        placeholders => {
                            LISTNAME => $list,
                            LISTURL => $bldata->{reference},
                            IP      => $ip,
                        },
                    });
                }
            }
        }
    }
    return \%tests;
}

sub _listtypes {
    my($self)= @_;
    my %listtypes;
    foreach my $bldata (values %{$self->{data}}) {
        my $kind= $bldata->{kind};
        if (ref $kind) {
            ++$listtypes{ uc $_ } foreach (values %$kind );
        } else {
            ++$listtypes{uc ($kind || '')};
        }
    }
    return [ sort keys %listtypes ];
}

# Retrieve blacklist data from filesystem if there is a newer one
# returns either
# 1: Successfully retrieved
# 0: Already up to date
# "error/warning message"
sub _retrieve {
    my($self)= @_;
    my $index= $self->{index};

    # Do we have a file with data?
    return "No such file: $index" unless -r $index;

    # get its age (relative to script start time)
    my $relative_age= -M _;

    # Is the current one up-to-date?
    return 0 if (exists $self->{data_read} and $relative_age >= $self->{data_read});

    # Load the newest list
    # print "Loading from filesystem\n";
    my $loaded= retrieve($index);
    if (not $loaded) {
        return "$index couldn't be loaded.";
    }
    if (ref $loaded ne 'HASH') {
        return "$index is of type ".ref($loaded)." but must be a HASH\n"
            ."Ignoring $index.";
    }
    $self->{data}= $loaded;
    $self->{data_read}= $relative_age;
    return 1;
}
1;
# b load /app/blacklist_checker/lib/Blacklists.pm