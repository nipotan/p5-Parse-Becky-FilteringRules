package Parse::Becky::FilteringRules::Rule;

use strict;
use warnings;
use Carp qw(croak);
use base qw(Class::Accessor::Fast);
use Parse::Becky::FilteringRules::Constants;

our $VERSION = '0.01';

__PACKAGE__->mk_accessors(qw(action purpose timing));

sub new {
    my($class, $params) = @_;
    $params = {} unless defined $params and ref($params) eq 'HASH';
    my $self = bless {
        timing => 'default',
        %$params
    }, $class;
    $self->{conditions} = [];
    return $self;
}

sub conditions {
    my($self, $conditions) = @_;
    if (defined $conditions) {
        croak "argument of conditions() method must be an arrayref"
            unless ref($conditions) eq 'ARRAY';
        $self->{conditions} = $conditions;
    }
    return wantarray ? @{$self->{conditions}} : $self->{conditions};
}

sub push_conditions {
    my($self, @conditions) = @_;
    my @current = $self->conditions;
    push @current, @conditions;
    $self->conditions(\@current);
}

sub as_string {
    my $self = shift;
    my $string = qq{:Begin ""} . CRLF;
    my $action;
    for my $key (keys %{FILTER_ACTIONS()}) {
        if (FILTER_ACTIONS->{$key} eq $self->action) {
            $action = $key;
            last;
        }
    }
    my $purpose = $self->purpose;
    if ($action eq 'L') { # server
        for my $key (keys %{FILTER_SERVER_ACTIONS()}) {
            if (FILTER_SERVER_ACTIONS->{$key} eq $purpose) {
                $purpose = $key;
                last;
            }
        }
    }
    $string .= sprintf("!%s:%s", $action, $purpose);
    $string .= CRLF;
    for my $condition ($self->conditions) {
        $string .= condition_as_string($condition);
    }
    if ($action eq 'M') {
        my $timing = 1;
        for my $key (keys %{FILTER_TIMINGS()}) {
            if (FILTER_TIMINGS->{$key} eq $self->timing) {
                $timing = $key;
                last;
            }
        }
        $string .= sprintf("\$O:Sort=%d", $timing);
        $string .= CRLF;
    }
    $string .= qq{:End ""} . CRLF;
    return $string;
}

sub condition_as_string {
    my $condition = shift;
    my $string = '';
    $string .= $condition->as_string . CRLF;
    if ($condition->has_additional_condition) {
        for my $and ($condition->additional_conditions) {
            $string .= condition_as_string($and);
        }
    }
    return $string;
}

1;
