package Parse::Becky::FilteringRules::Condition;

use strict;
use warnings;
use Carp qw(croak);
use base qw(Class::Accessor::Fast);

our $VERSION = '0.01';

__PACKAGE__->mk_accessors(
    qw(depth header value true ignore_case as_a_word line_head regexp)
);

sub new {
    my($class, $params) = @_;
    $params = {} unless defined $params and ref($params) eq 'HASH';
    my $self = bless {
        true        => 1,
        ignore_case => 1,
        as_a_word   => 0,
        line_head   => 0,
        regexp      => 0,
        depth       => 0,
        and         => [],
        %$params
    }, $class;
    return $self;
}

sub additional_conditions {
    my($self, $conditions) = @_;
    if (defined $conditions) {
        croak "argument of additional_conditions() method must be an arrayref"
            unless ref($conditions) eq 'ARRAY';
        $self->{and} = $conditions;
    }
    return wantarray ? @{$self->{and}} : $self->{and};
}

sub push_additional_conditions {
    my($self, @conditions) = @_;
    my @current = $self->additional_conditions;
    push @current, @conditions;
    $self->additional_conditions(\@current);
}

sub has_additional_condition {
    my $self = shift;
    my @additional = $self->additional_conditions;
    return scalar(@additional) ? 1 : ();
}

sub as_string {
    my $self = shift;
    my $true_or_false = $self->true ? 'O' : 'X';
    my $flags = '';
    $flags .= 'I' if $self->ignore_case;
    $flags .= 'W' if $self->as_a_word;
    $flags .= 'T' if $self->line_head;
    $flags .= 'R' if $self->regexp;
    my $string =
        sprintf("@%d:%s:%s\t%s\t%s",
            $self->depth, $self->header, $self->value, $true_or_false, $flags);
    return $string;
}

1;
