package SiwecosResult;
use strict;
use warnings;
use Mojo::JSON qw(to_json);

sub new {
    my($class, $preset)= @_;
    $class= ref($class) || $class;
    my $self= {
        name => $preset->{name},
        version => $preset->{version},
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
            qw( name version hasError errorMessage score )
        )
    .   ',"tests":'
    .   '['
    .       join (',', map
                $_->to_String(),
                @{$self->{tests}}
            )
    .   ']'
    .'}';
}

sub calc_score {
    my($self)= @_;
    my $score= undef;
    my $count= 0;
    foreach my $test (@{$self->{tests}}) {
        $score+= $test->score;
        ++$count;
    }
    if ($count) {
        $self->{score}= $score= int($score/$count);        
    }
    return $self->{score};
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

sub version {
    my($self, $version)= @_;
    if (defined $version) {
        $self->{version}= $version;
    }
    return $self->{version};
}

sub score {
    my($self, $score)= @_;
    if (defined $score) {
        $self->{score}= int $score;
    }
    return $self->{score};
}

sub add_test {
    my($self, $test)= @_;
    $self->{tests}||= [];
    push @{$self->{tests}}, $test;
}

sub tests {
    my($self)= @_;
    return $self->{tests};
}

1;

