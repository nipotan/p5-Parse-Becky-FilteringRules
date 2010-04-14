package Parse::Becky::FilteringRules::Constants;

use strict;
use warnings;
use base qw(Exporter);

our $VERSION = '0.01';
our @EXPORT = qw(FILTER_ACTIONS FILTER_TIMINGS FILTER_SERVER_ACTIONS CRLF);

use constant FILTER_ACTIONS => +{
     C => 'color',
     F => 'forward',
     G => 'flag',
     L => 'server',
     M => 'sort',
     R => 'reply',
     S => 'sound',
     X => 'execute',
     Y => 'copy',
};

use constant FILTER_TIMINGS => +{
    1 => 'default',
    2 => 'auto',
    3 => 'manual',
};

use constant FILTER_SERVER_ACTIONS => +{
    '0 0' => 'leave',
    '1 0' => 'delete',
    '1 1' => 'kill',
};

use constant CRLF => "\x0D\x0A";

1;
