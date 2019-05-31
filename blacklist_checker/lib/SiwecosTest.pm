package SiwecosTest;
use strict;
use warnings;
use Mojo::JSON qw(to_json);

sub new {
    my($class, $preset)= @_;
    $class= ref($class) || $class;
    my $self= {
        name => $preset->{name},
        hasError => Mojo::JSON::false,
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
            qw( name hasError errorMessage score scoreType )
        )
    .   ',"testDetails":'
    .   '['
    .       join (',', map
                $_->to_String(),
                @{$self->{testDetails}}
            )
    .   ']'
    .'}';
}

sub errorMessage {
    my($self, $errorMessage)= @_;
    if (defined $errorMessage) {
        $errorMessage= undef if $errorMessage eq '';
        $self->{errorMessage}= $errorMessage;
        $self->{hasError}= defined $errorMessage ? Mojo::JSON::true : Mojo::JSON::false;
    }
    return $self->{errorMessage};
}

sub hasError {
    my($self)= @_;
    return $self->{hasError};
}

sub name {
    my($self, $name)= @_;
    if (defined $name) {
        $self->{name}= $name;
    }
    return $self->{name};
}

sub scoreType {
    my($self, $scoreType)= @_;
    if (defined $scoreType) {
        $self->{scoreType}= $scoreType;
    }
    return $self->{scoreType};
}

sub score {
    my($self, $score)= @_;
    if (defined $score) {
        $self->{score}= int $score;
    }
    return $self->{score};
}

sub add_testDetails {
    my($self, @testDetails)= @_;
    $self->{testDetails}||= [];
    push @{$self->{testDetails}}, @testDetails;
}

sub testDetails {
    my($self)= @_;
    return $self->{testDetails};
}

1;

