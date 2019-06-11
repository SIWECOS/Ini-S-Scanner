package BtreeFile;

use strict;
use warnings;
use Carp;

sub new {
    my($class, $filename, $sorted_array)= @_;
    $class= ref $class || $class;
    my $self= {
        filename => $filename,
    };
    bless $self, $class;
    if ($sorted_array) {
        $self->save($sorted_array);
    }
    return $self;
}

sub save {
    my($self, $sorted_array)= @_;
    open my $btree_file, ">", $self->{filename}
        or croak "Cannot create ".$self->{filename}.": $!";
    print $btree_file scalar @$sorted_array,"\n";
    print $btree_file _btree($sorted_array, 0, $#$sorted_array);
    close $btree_file;
}

sub reverse_domain_match {
    my($self, $domain)= @_;
    my $length= length($domain);
    my $search_for= scalar reverse $domain;
    my $found= "";
    open my $btree_file, '<', $self->{filename}
        or croak "Cannot read ".$self->{filename}.": $!";
    my $entries= <$btree_file>;
    while (my $e= <$btree_file>) {
        chomp $e;
        last unless $e;
        my $offset= <$btree_file>;
        my $cmp= $search_for cmp substr($e, 0, $length);
        next if $cmp < 0;
        if ($cmp) {
            last unless 1*$offset;
            seek $btree_file, $offset, 1;
            next;
        }
        # It's only a match if the entry matched complete
        # ( eq '' ) or the next character is '.'.
        # otherwise the searched entry is less than what was found.
        my $check_end= substr($e, $length, 1);
        next if $check_end ne '' and $check_end ne '.';
        $found= $e;
        last;
    }
    close $btree_file;
    return scalar reverse $found;
}


sub _btree {
    my($arr, $l, $r)= @_;  # array, left and right border
    return "" if $l > $r;  # done if out of array
    my $m= ($r+$l+1) >> 1; # get middle entry
    my $smaller= _btree($arr, $l, $m-1); # btree of smaller entries
    my $bigger=  _btree($arr, $m+1, $r); # btree of bigger entries
    if (not $smaller) {   # No entries smaller
        $smaller= "\n";   # will become an empty line
    }
    my $offset= 0;                 # how much to seek forward
    if ($bigger) {                 # Something bigger?
        $offset= length($smaller); # then skip over the smaller entries
    }
    return 
        $arr->[$m] . "\n" .
        $offset . "\n" .
        $smaller .
        $bigger;
}

1;