package Parse::Becky::FilteringRules;

use strict;
use warnings;
use Carp qw(croak);
use base qw(Class::Accessor::Fast);
use Parse::Becky::FilteringRules::Rule;
use Parse::Becky::FilteringRules::Condition;
use Parse::Becky::FilteringRules::Constants;
use String::CamelCase qw(decamelize);
use IO::File;
use Clone qw(clone);

our $VERSION = '0.01';

__PACKAGE__->mk_accessors(
    qw(version auto_sorting only_read only_one_folder)
);

sub new {
    my($class, $params) = @_;
    $params = {} unless defined $params and ref($params) eq 'HASH';
    my $self = bless { # defaults
        version         => 1,
        auto_sorting    => 1,
        only_read       => 0,
        only_one_folder => 1,
        %$params,
    }, $class;
    $self->{rules} = [];
    return $self;
}

sub parse {
    my($self, $f) = @_;

    my $fh = ref($f) ? $f : (IO::File->new($f) or croak "$f: $!");
    binmode $fh; # for win32
    local $/ = CRLF;

    my $is_begun;
    my %rule = ();
    my @conditions = ();
    my $last_depth = 0;

    while (my $line = <$fh>) {
        chomp $line;
        if ($line =~ /^(Version|AutoSorting|OnlyRead|OnlyOneFolder)=(.+)$/) {
            my $method = decamelize($1);
            $self->$method($2);
            next;
        }
        if ($line eq ':Begin ""') {
            $is_begun = 1;
            next;
        }
        if ($line eq ':End ""') {
            $is_begun = 0;
            my $rule = Parse::Becky::FilteringRules::Rule->new(clone(\%rule));
            my $cond = clone(\@conditions);
            $rule->conditions($cond);
            $self->push_rules($rule);
            @conditions = ();
            %rule       = ();
            next;
        }
        next unless $is_begun;

        # rule start
        if (my($action, $purpose) = $line =~ /^!([CFGLMRSXY]):(.+)$/) {
            $rule{action} = FILTER_ACTIONS->{$action};
            if ($action eq 'G') {
                my @purposes = ();
                push @purposes, 'flag' if $purpose =~ /F/;
                push @purposes, 'read' if $purpose =~ /R/;
                $rule{purpose} = \@purposes;
                next;
            }
            if ($action eq 'F') {
                my %purposes = ();
                ($purposes{template}, $purposes{recipient}) =
                    split /\*/, $purpose;
                $rule{purpose} = \%purposes;
                next;
            }
            if ($action eq 'L') {
                $rule{purpose} = FILTER_SERVER_ACTIONS->{$purpose};
                next;
            }
            $rule{purpose} = $purpose;
            next;
        }

        # sort timings
        if ($line =~ /^\$O:Sort=([1-3])/) {
            $rule{timing} = FILTER_TIMINGS->{$1};
            next;
        }

        # conditions
        if ($line =~ /^\@/) {
            my($depth, $header, $value, $true_or_false, $flags) =
                $line =~ /^\@(\d+):(.+?):(.+?)\t+([OX])\t+([IWTR]*)$/;
            croak "couldn't parse line: $line" unless $true_or_false;
            my %cond = (
                depth  => $depth,
                header => $header,
                value  => $value,
            );
            $cond{true}        = $true_or_false eq 'O' ? 1 : 0;
            $cond{ignore_case} = $flags =~ /I/ ? 1 : 0;
            $cond{as_a_word}   = $flags =~ /W/ ? 1 : 0;
            $cond{line_head}   = $flags =~ /T/ ? 1 : 0;
            $cond{regexp}      = $flags =~ /R/ ? 1 : 0;
            if (!$cond{line_head} && $cond{regexp} && $value =~ m{^\^}) {
                $cond{line_head} = 1;
            }
            my $cond = Parse::Becky::FilteringRules::Condition->new(\%cond);
            unless ($depth) { # @0
                push @conditions, $cond;
                next;
            }
            my $bottom_rule = $conditions[$#conditions];
            if ($depth == 1) {
                $bottom_rule->push_additional_conditions($cond);
                next;
            }
            for my $i (2 .. $depth) {
                my @and = $bottom_rule->additional_conditions;
                $bottom_rule = $and[$#and];
            }
            $bottom_rule->push_additional_conditions($cond);
        }
    }
    return $self;
}

sub rules {
    my($self, $rules) = @_;
    if (defined $rules) {
        croak "argument of rules() method must be an arrayref"
            unless ref($rules) eq 'ARRAY';
        $self->{rules} = $rules;
    }
    return wantarray ? @{$self->{rules}} : $self->{rules};
}

sub push_rules {
    my($self, @rules) = @_;
    my @current_rules = $self->rules;
    push @current_rules, @rules;
    $self->rules(\@current_rules);
}

sub as_string {
    my $self = shift;
    my $string = '';
    for my $settings (qw(Version AutoSorting OnlyRead OnlyOneFolder)) {
        my $method = decamelize($settings);
        $string .= sprintf("%s=%d", $settings, $self->$method());
        $string .= CRLF;
    }
    my @rules = $self->rules;
    for my $rule (@rules) {
        $string .= $rule->as_string;
    }
    return $string;
}

1;

__END__

=head1 NAME

Parse::Becky::FilteringRules - Parse a filtering rule file of Becky! Internet Mail

=head1 SYNOPSIS

Parsing a created rule file:

 use Parse::Becky::FilteringRules;
 
 my $bk = Parse::Becky::FilteringRules->new;
 $bk->parse('/Becky!/user_name/42648b9e.mb/IFilter.def');

Creating a new rule:

 use Parse::Becky::FilteringRules;
 use Parse::Becky::FilteringRules::Rule;
 use Parse::Becky::FilteringRules::Condition;
 
 my $cond = Parse::Becky::FilteringRules::Condition->new;
 $cond->depth(0);
 $cond->header('From');
 $cond->value('taniguchi@cpan.org');
 $cond->true(0);
 
 my $additional_cond = Parse::Becky::FilteringRules::Condition->new({
     depth  => 1,
     header => '[body]',
     value  => 'V.?[I1].?A.?G.?R.?A.?',
 });
 $cond->push_additional_conditions($additional_cond);
 
 my $rule = Parse::Becky::FilteringRules::Rule->new;
 $rule->action('sort');
 $rule->purpose('42648b9e.mb\!!!!Inbox\spam\\');
 
 $rule->push_conditions($cond);
 
 my $bk = Parse::Becky::FilteringRules->new;
 $bk->push_rules($rule);
 
 print $bk->as_string;

=head1 DESCRIPTION

Parse::Becky::FilteringRules is a parser class of filtering rule files of
Becky! Internet Mail.
Becky! Internet Mail is a Japanese famous mail user agent and you can download
it at L<http://www.rimarts.co.jp/>.

=head1 AUTHOR

Koichi Taniguchi E<lt>taniguchi@livedoor.jpE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
