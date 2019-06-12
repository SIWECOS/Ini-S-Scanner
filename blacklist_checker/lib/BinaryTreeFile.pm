package BinaryTreeFile;
=encoding utf8

=head1 NAME

BinaryTreeFile

=head1 SYNOPSIS

    use BinaryTreeFile;

Initialize the BinaryTreeFile
    my $bintree= BinaryTreeFile->new( $filename );
    my $bintree= BinaryTreeFile->new( $filename, \@sorted_array );

Save a sorted array as a binary tree file
    my $result= $bintree->save( \@sorted_array );

Check a domain
    my $res= $bintree->reverse_domain_match( $domain );

=head1 DESCRIPTION

BinaryTreeFile is an efficient storage for binary tree search in files.

B<Note:> This module was written with the Initiative-S Scanner for
SIWECOS in mind. While it can be enhanced to support regular searches,
its main focus is to find domains in a list of domains. Please see
the Note under L<reverse_domain_match>.

=head1 METHODS

=cut

use strict;
use warnings;
use Carp;

=head2 new

(Class method) Returns a new instance of class BinaryTreeFile.

    my $bintree = BinaryTreeFile->new ( $filename [, \@sorted_array] );

$bintree is undef in case the array couldn't be saved.

Errormessage will be carp-ed.

=cut

sub new {
    my($class, $filename, $sorted_array)= @_;
    $class= ref $class || $class;
    my $self= {
        filename => $filename,
    };
    bless $self, $class;
    if ($sorted_array) {
        return undef unless $self->save($sorted_array);
    }
    return $self;
}

=head2 save

Saves a sorted array in a BinaryTreeFile.

    my $result= $bintree->save( \@sorted_array );

$result is undef in case the array couldn't be saved.

Errormessage will be carp-ed.

=cut

sub save {
    my($self, $sorted_array)= @_;
    open my $bintree_file, ">", $self->{filename}.$$
        or do {
            carp "Cannot create ".$self->{filename}."$$: $!";
            return undef;
        };
    print $bintree_file scalar @$sorted_array,"\n";
    print $bintree_file _bintree($sorted_array, 0, $#$sorted_array);
    close $bintree_file;
    rename $self->{filename}.$$, $self->{filename}.$$
         or do {
            carp "Failed to rename ".$self->{filename}."$$ to ".$self->{filename}.": $!";
            return undef;
        };
   return 1;
}

=head2 reverse_domain_match

Saves a sorted array in a BinaryTreeFile.

    my $result= $bintree->reverse_domain_match( $domain );

$result is undef in case the file couldn't be read.

$result will be the empty string if no match was found.

Otherwise $result will be the closest match found.

Errormessage will be carp-ed.

B<Note:> For the reverse_domain_match to work, the sorted
array, which was saved as a BinaryTreeFile, must contain the
reversed domain strings. This has to be done before calling
B<save>.

When searching a match for $domain, the domain string is reversed.
Then a Prefix-Match (which is a suffix match, since everything
is reversed) is searched. When a prefix matched the complete
string or up to a dot (.), a match is found.

=cut

sub reverse_domain_match {
    my($self, $domain)= @_;
    my $length= length($domain);
    my $search_for= scalar reverse $domain;
    my $found= "";
    open my $bintree_file, '<', $self->{filename}
        or do {
            carp "Cannot read ".$self->{filename}.": $!";
            return undef;
        };
    my $entries= <$bintree_file>;
    while (my $e= <$bintree_file>) {
        chomp $e;
        last unless $e;
        my $offset= <$bintree_file>;
        my $cmp= $search_for cmp substr($e, 0, $length);
        next if $cmp < 0;
        if ($cmp) {
            last unless 1*$offset;
            seek $bintree_file, $offset, 1;
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
    close $bintree_file;
    return scalar reverse $found;
}

#
# _bintree will save a sorted array as a balanced binary tree
# The file contains the number of entries in the first line.
# All following lines are nodes in the tree. They either consist of
# 1. One empty line. This means that there are no further
#    entries in this branch
# 2. An entry line followed by an offset to the bigger entries.
#    If the offset is 0, there are no bigger entries
# so the array a b c d e f g h will result in this tree:
#     ,---e---,
#   ,-c-,   ,-g-,
# ,-b   d   f   h
# a
# and will be saved like this:
# 8    # Number of entries
# e    # root entry
# 18   # 18 bytes to seek forward to reach "g"
# c    # entry "c"
# 9    # 9 bytes to seek forward to reach "d"
# b    # entry "b"
# 0    # no more bigger entries then "b"
# a    # entry "a"
# 0    # no more bigger entries than "a"
#      # also no smaller entries than "a"
# d    # …
# 0
# 
# g
# 5
# f
# 0
# 
# h
# 0


sub _bintree {
    my($arr, $l, $r)= @_;  # array, left and right border
    return "" if $l > $r;  # done if out of array
    my $m= ($r+$l+1) >> 1; # get middle entry
    my $smaller= _bintree($arr, $l, $m-1); # bintree of smaller entries
    my $bigger=  _bintree($arr, $m+1, $r); # bintree of bigger entries
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