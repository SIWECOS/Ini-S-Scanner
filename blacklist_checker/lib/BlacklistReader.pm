package BlacklistReader;

use strict;
use warnings;
use Carp;
use Net::IDN::Encode qw(domain_to_ascii);
use Text::CSV;
use URI;

sub new {
    my($class, $id, $config)= @_;
    $class= ref($class) || $class;
    my $self= {
        id      => $id,
        config  => $config,
    };
    bless $self, $class;
    $self->_initialize() or return undef;
    return $self;
}

# Initialization merely checks that the
# configuration is okay.
sub _initialize {
    return _check(@_);
}

sub _check {
    my($self)= @_;
    if ( not defined $self->{id} ) {
        carp "Missing blacklist id";
        return undef;
    }
    if ( not defined $self->{config} ) {
        carp "Missing blacklist config for ".$self->{id};
        return undef;
    }
    my $error= "";
    foreach my $required (qw( reader kind reference url )) {
        next if defined $self->{config}->{$required};
        $error.= "$required not defined for ".$self->{id}."\n";
    }
    my $url= $self->{config}->{url};
    if (defined $url and $url !~ m#^(file:///?|https?://)\w+#) {
        $error.= "no valid url defined for ".$self->{id};
    }
    my $reader= $self->{config}->{reader};
    if (defined $reader) {
        if ($reader->{start}) {
            if ('Regexp' ne ref $reader->{start}
                and $reader->{start}!~ /^\d+$/) {
                $error.= "start ".$reader->{start}." for ".$self->{id}." is neither a number nor a regexp.\n";
            }
        }
        if ($reader->{header}) {
            $error.= "No separator regexp defined for ".$self->{id}.".\n" unless $reader->{separator} or $reader->{'Text::CSV'};
            if ('Regexp' ne ref $reader->{header}
                and $reader->{header}!~ /^\d+$/) {
                $error.= "header ".$reader->{header}." for ".$self->{id}." is neither a number nor a regexp.\n";
            }
            if (not defined $reader->{column}) {
                $error.= "header set but no column defined for ".$self->{id}."\n";
            }
        } elsif (defined $reader->{column}) {
            if ($reader->{column}=~ /^\d+$/) {
                if ($reader->{column} < 1) {
                    $error.= "Column 0 for ".$self->{id}." is not a valid column index. Columns are 1-based.\n";
                }
            } else {
                $error.= "Column ".$reader->{column}." for ".$self->{id}." is not a valid column number.\n";
            }
        }
    }
    if ($error) {
        carp $error;
        return undef;
    }
    return 1;
}

# Function to fetch a blacklist from external source
sub fetch {
    my($self, $last_date)= @_;
    return undef unless $self->_check;
    my $config= $self->{config};
    my $reader= $config->{reader};
    # Retrieve the blacklist
    # the do-block will split into lines
    my ($last_modified, @lines)= do {
        my $url= $config->{url};
        if ($url=~ s#^file://##) {
            my(@stat)= stat $url;
            if (not @stat) {
                carp "No such file: $url.\n";
                return undef;
            }
            return 0 if $last_date and $stat[9] <= $last_date;
            if (open my $cached_file, '<', $url) {
                my $lines= do {
                    local $/;
                    <$cached_file>;
                };
                close $cached_file;
                ($stat[9], split /[\012\015]+/, $lines);
            } else {
                carp "Couldn't read $url: $!\n";
                return undef;
            }
        } else {
            my $ua= Mojo::UserAgent->new;
            $ua->max_redirects(3);
            
            if ($last_date) {
                # Test the last-modified before downloading
                # Try to get the data from external server or fail
                my $res= _checked_result($ua->head($url)) or return undef;
                # Check the date as reported by the external server
                my $date= Mojo::Date->new( $res->headers->last_modified || time);
                if ($date->epoch <= $last_date) {
                    return 0;
                }
            }

            # Retrieve the blacklist
            my $res = _checked_result($ua->get($url)) or return undef;
            my $date= Mojo::Date->new( $res->headers->last_modified || time);
            ($date->epoch, split /[\012\015]+/, $res->body);
        }
    };
    # Startline defined?
    my $line= 0;
    if ($reader->{start}) {
        if ('Regexp' eq ref $reader->{start}) {
            # Skip up to line where there is the start-qr// found
            1 while ( $line < $#lines and $lines[$line++] !~ $reader->{start});
        } elsif ($reader->{start}=~ /^\d+$/) {
            # Or skip to the defined line (minus 1)
            $line+= $reader->{start} - 1;
        } # no else as _check already did verify
    }
    # Erase all comments
    if ($reader->{comments}) {
        foreach (@lines) {
            s/$reader->{comments}//;
        }
    }
    my $sep= $reader->{separator} if 'Regexp' eq ref $reader->{separator};
    if ($reader->{'Text::CSV'}) {
        $sep= Text::CSV->new( $reader->{'Text::CSV'} ) or do {
            carp "Could not create a Text::CSV reader";
            return undef;
        }
    }
    my $column= $reader->{column};
    my $cleaner= $reader->{cleaner};
    if ('Regexp' eq ref $cleaner) {
        $cleaner= sub { $_[0]=~ $reader->{cleaner}; return $1; };
    } elsif ($cleaner and 'URI' eq $cleaner ) {
        $cleaner= sub { 
            my $u= URI->new($_[0]);
            return $u->has_recognized_scheme && $u->host;
        };
    } else {
        $cleaner= undef;
    }
    my $column_index= 0;
    # Is there a header-line? Then there must be a separator as well
    if ($reader->{header}) {
        # if the header line is empty (maybe comments which were deleted), search for a non empty line first
        while ($line < $#lines and $lines[$line]=~ /^\s*$/) {
            ++$line;
        }
        my $header;
        # If header is a regexp, we read until we find it
        if ('Regexp' eq ref $reader->{header}) {
            while ($line < $#lines and $lines[$line]!~ $reader->{header}) {
                ++$line;
            }
            if ($lines[$line++]=~ $reader->{header}) {
                my $header= _split($sep, $1) or return undef;
            } # no else as _check already did verify
        } elsif ($reader->{header}=~ /^\d+$/) {
            $line+= $reader->{header};
            $header= _split($sep, $lines[$line-1]) or return undef;
        } # no else as _check already did verify
        my %header;
        @header{@$header}= (0..$#$header);
        carp "No column in ".$self->{id}." is labeled $column.\n" unless exists $header{$column};
        $column_index= $header{$column};
    } elsif (defined $column) {
        if ($column=~ /^\d+$/) {
            $column_index= $column - 1; 
        }
    }
    # Erase all line content above current line
    for (my $i=0; $i<$line; ++$i) {
        $lines[$i]= '';
    }
    if ($sep) {
        # If we have a separator we need to split each line
        if ($cleaner) {
            # If we also have a cleaner we need to clean each value
            while ($line <= $#lines) {
                my $c= _split($sep, $lines[$line]) or return undef;
                $lines[$line++]= $cleaner->($c->[$column_index] || '') || '';
            }
        } else {
            # No cleaner defined.
            while ($line <= $#lines) {
                my $c= _split($sep, $lines[$line]) or return undef;
                $lines[$line++]= $c->[$column_index] || '';
            }
        }
    } else {
        # No separator
        if ($cleaner) {
            # But a cleaner. So the full line is cleaned
            while ($line <= $#lines) {
                $lines[$line++]= $cleaner->($lines[$line]) || '';
            }
        }
        # If no cleaner and no separator we take the full line to be our domain
    }
    my %seen;
    my $out;
    # Data is now cleaned.
    # Every non-empty line is now a domain
    # But domains can occure multiple times
    # We just want unique entries
    my $i=0;
    foreach (@lines) {
        # the entry may not be empty
        next unless $_;
        next if /^\s*$/;
        # do punycode encoding
        $_= domain_to_ascii($_);
        # if we haven't seen that domain yet
        if (not $seen{$_}++) {
            # we store it for output
            $lines[$i++]= $_;
        }
    }
    splice @lines, $i;
    return {
        updated => $last_modified,
        domains => \@lines,
    };
}

sub id {
    my($self)= @_;
    return $self->{id};
}

sub kind {
    my($self)= @_;
    return $self->{config}->{kind};
}

sub reference {
    my($self)= @_;
    return $self->{config}->{reference};
}

sub _split {
    my($csv_reader, $line)= @_;
    if ('Text::CSV' eq ref $csv_reader) {
        if (not $csv_reader->parse($line)) {
            carp "Could not parse $line with Text::CSV";
            return undef;
        }
        return [ $csv_reader->fields ];
    }
    return [ split $csv_reader, $line ];
}

sub _checked_result {
    my($http)= @_;
    if (my $err= $http->error) {
        carp $err->{code}." response: ".$err->{message};
        return undef;
    }
    my $res= eval { $http->result };
    if (not $res->is_success) {
        if ($res->is_error)    {
            carp "Failed to download ".$http->req->url."\n\t".$res->message."\n";
            return undef;
        }
        if ($res->code == 301) {
            carp "Too many redirects for ".$http->req->url."\n\t".$res->headers->location."\n";
            return undef;
        }
        carp "Failed to download ".$http->req->url."\n\tfor unknown reason\n";
        return undef;
    }
    return $res;
}

1;
# b load /home/blacklist_checker/script/../lib/BlacklistReader.pm

=encoding utf8

=head1 NAME

BlacklistReader

=head1 SYNOPSIS

    use BlacklistReader;

    # Initialize the BlacklistReader
    my %blr= BlacklistReader->new(
        'listname' => \%config
    ) 

    # Update the blacklist
    my $res= $blr->fetch( $last_update_date );
    if ( not defined $res ) {
        # update failed
    } elsif (ref $res) {
        # updated
        # $res->{domains} will be the list of unique domains, punycode-encoded
        # $res->{updated} will be the list's update-date
    } else {
        # already up to date
    }

    # get information
    my $id= $blr->id;
    my $kind= $blr->kind;
    my $reference= $blr->reference;

=head1 DESCRIPTION

BlacklistReader is mainly used by BlacklistDB.

It's used to store configuration information about the blacklist, and to
download the domains of a blacklist.

=head1 CONFIGURATION

The configuration is a hash with these properties:

=over 4

=item reference

Reference address to show to the customer

=item kind

What kind of blacklist (Just information) Phishing|Spam|Malware|…

=item url

Address where to download from

=item reader

Reader definition. This is a hash with some of these properties:

=over 4

=item seperator

This should be a regular expression defining the value separators.

=item header

Which linenumber is the header line. That many lines will be skipped.

Alternatively this can be a regular expression which will match the
header line. The relevant part of the header line must be captured
in $1. The header line will then be splitted using the I<seperator>.

=item column

Name or index of the column containing the data.

=item start

Line which indicates the start of the data. The line itself will be ignored

=item comments

A regular expression to remove comments from the blacklist.

=item cleaner

A regular expression which must capture in $1 the data to use.

=back

=back

# b load /home/blacklist_checker/script/../lib/BlacklistReader.pm
