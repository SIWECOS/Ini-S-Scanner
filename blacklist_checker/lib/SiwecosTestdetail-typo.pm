package SiwecosTestDetail;
use strict;
use warnings;
use Mojo::JSON qw( to_json );

sub new {
    my($class, $preset)= @_;
    $class= ref($class) || $class;
    my $self= {
        translationStringId => $preset->{translationStringId},
        placeholders => $preset->{placeholders},
    };
    bless $self, $class;
    return $self;
}

sub to_String {
    my($self) = @_;
    my $result
    ='{'
    .   join(',', map
            to_json($_) . ':' . to_json( $self->{$_} ),
            qw( translationStringId placeholders )
        )
    .'}';
}
sub translationStringId {
    my($self, $translationStringId)= @_;
    if (defined $translationStringId) {
        $self->{translationStringId}= $translationStringId;
    }
    return $self->{translationStringId};
}

sub add_placeholders {
    my($self, $placeholders)= @_;
    $self->{placeholders}||= {};
    while (my($k, $v)= each(%$placeholders)) {
        $placeholders->{$k}= $v;
    }
}

sub placeholders {
    my($self)= @_;
    return $self->{placeholders};
}

1;