package Blacklists;
=encoding utf8

=head1 NAME

Blacklists

=head1 SYNOPSIS

    use Blacklists;

    # Initialize the Blacklists
    my %bls= Blacklists->new( {
        storage  => '/path/to/storage',
        lists    => { list config },
        severity => { severity config },
      }
    ) 

    # Check a domain
    my $res= $bls->check_domain( $domain );
    # Returns a hash in SIWECOS-Result-Format 
    
    # get information
    my $bl= $bls->blacklistfile( $id );

    my $order= $blfs->listorder;
    # @$order is an unsorted list of all blacklistfile IDs
    
    my $last_read= $blfs->last_read;
    # epoch time of last time files were read from filesystem

    my $last_fetch= $blfs->last_fetch;
    # epoch time of the youngest blacklistfile

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
use SiwecosResult;
use SiwecosTest;
use SiwecosTestDetail;

use Mojo::UserAgent;
use Mojo::JSON;
use Net::IDN::Encode qw(:all);

use Storable qw( nstore retrieve );

=head2 new

(Class method) Returns a new instance of class Blacklists. The
attributes are described by a hash ref.

my $bls = Blacklists->new ({ attributes ... });

The following attributes are available:

=over 4

=item storage

Defines a path to the file, where the Blacklists' data is stored.

my $bls = Blacklists->new ({ storage => '/path/to/blacklists.data', ... });

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
                updated => 0,
                domains => {},
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
    PREPARE_STORAGE:{ if ($storage) {
        if (not -r $storage) {
            if (not nstore($self->{data}, $storage)) {
                $error.= "Couldn't create $storage.\n";
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


sub update {
    my($self)= @_;
    # remove all loaded blacklists (data) which are no longer configured
    while (my($blacklist_id, $bldata)= each %{$self->{data}}) {
        if (not exists $self->{readers}{$blacklist_id}) {
            delete $self->{data}{$blacklist_id};
        }
    }
    # prepare all blacklists configured but not yet loaded
    foreach my $configured_blacklist_name (keys %{$self->{readers}}) {
        next if exists $self->{data}{$configured_blacklist_name};
        $self->{data}{$configured_blacklist_name}= {
            updated   => 0,
            domains   => {},
        };
    }
    # Update/load all configured lists
    my $updated= 0;
    foreach my $blacklist_id (keys %{$self->{data}}) {
        my $reader= $self->{readers}{$blacklist_id};
        next unless $reader;
        my $last_modified= $self->{data}{$blacklist_id}{updated};
        my $updated_list= $reader->fetch($last_modified);
        carp "Could not update $blacklist_id" unless defined $updated_list;
        next unless $updated_list;
        ++$updated;
        my %domains;
        @domains{@{$updated_list->{domains}}}=();
        $self->{data}{$blacklist_id}= {
            updated   => $updated_list->{updated},
            domains   => \%domains,
            kind      => $reader->{config}{kind},
            reference => $reader->{config}{reference},
        }
    }
    # If anything was updated, store as temporary file
    if ($updated and nstore($self->{data}, $self->{storage}.$$)) {
        # when stored overwrite existing file
        rename $self->{storage}.$$, $self->{storage}; 
    }
    $self->{listtypes}= $self->_listtypes;
    return 1;
}

=head2 get_lists

Will return a reference to all blacklists

=cut

sub get_lists {
    my($self)= @_;
    return $self->{data};
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
        s#^https?://##;
        s#[:/].*$##;
    }
    # find the alternativ (toggle "www")
    my $alternative= $domain;
    if (not $alternative=~ s/^www\.//) {
        $alternative= "www.$domain";
    }
    # check domain and www.domain
    my $matches= $self->_checkmatch($domain);
    my $alternative_match= $self->_checkmatch($alternative);

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
        # Get the results for the original domain
        my $result= $matches->{$kind};
        if ($result) {
            $new_details||= 1;
            foreach my $listname (sort keys %{$result}) {
                $test->add_testDetails($result->{$listname});
            }
        }
        # Get the results for the alternative domain
        $result= $alternative_match->{$kind};
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
        next unless exists $bldata->{domains}{$domain};
        # Store the information as a SiwecosTestDetail
        $tests{uc $bldata->{kind}}{$list}= SiwecosTestDetail->new({
            translationStringId => 'DOMAIN_FOUND',
            placeholders => {
                LISTNAME => $list,
                LISTURL => $bldata->{reference},
                DOMAIN => $domain,
            },
        });
    }
    return \%tests;
}

sub _listtypes {
    my($self)= @_;
    my %listtypes;
    foreach my $bldata (values %{$self->{data}}) {
        ++$listtypes{uc $bldata->{kind}};
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
    my $storage= $self->{storage};

    # Do we have a file with data?
    return "No such file: $storage" unless -r $storage;

    # get its age (relative to script start time)
    my $relative_age= -M _;

    # Is the current one up-to-date?
    return 0 if (exists $self->{data_read} and $relative_age >= $self->{data_read});

    # Load the newest list
    my $loaded= retrieve($storage);
    if (not $loaded) {
        return "$storage couldn't be loaded.";
    }
    if (ref $loaded ne 'HASH') {
        return "$storage is of type ".ref($loaded)." but must be a HASH\n"
            ."Ignoring $storage.";
    }
    $self->{data}= $loaded;
    $self->{data_read}= $relative_age;
    return 1;
}
1;
# b load /home/blacklist_checker/script/../lib/Blacklists.pm