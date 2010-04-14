use inc::Module::Install;
name 'Parse-Becky-FilteringRules';
all_from 'lib/Parse/Becky/FilteringRules.pm';

requires 'Class::Accessor::Fast';
requires 'String::CamelCase';
requires 'Clone';

perl_version '5.008001';
build_requires 'Test::More';

use_test_base;
auto_include;
WriteAll;
