#!/usr/bin/env perl
#
# Ref:
#     https://labs.omniti.com/pgtreats/trunk/tools/pg.grep
#

package main;
Pg::Grep->new()->run();
exit;

package Pg::Grep;
use strict;
use warnings;
use English qw( -no_match_vars );
use Getopt::Long qw( :config no_ignore_case );
use Data::Dumper;
use IO::Handle;

sub new {
    my $class = shift;
    return bless {}, $class;
}

sub run {
    my $self = shift;
    $self->{'out'} = \*STDOUT;
    $self->read_args();

    $self->{'current_buffer'} = '';

    my $base_re = $self->{'line_prefix'};
    my $line_type_re = $self->{'line'} ? qr{} : qr{ (?: DEBUG[1-5] | INFO | NOTICE | WARNING | ERROR | LOG | FATAL | PANIC ) : \s\s }x;

    while ( my $line = <> ) {
        if ( $line =~ m{\A$base_re$line_type_re} ) {
            $self->match_current_buffer();
            $self->{'current_buffer'} = '';
        }
        $self->{'current_buffer'} .= $line;
    }
    $self->match_current_buffer();
    return;
}

sub match_current_buffer {
    my $self = shift;
    my $result = 's';
    for my $m ( @{ $self->{'matchers'} } ) {
        my ($type, $re) = @{ $m };
        last unless $self->{'current_buffer'} =~ $re;
        $result = $type;
    }
    if ( 'm' eq $result ) {
        print $self->{'current_buffer'};
        $self->{'out'}->flush();
    }
    return;
}

sub read_args {
    my $self = shift;
    my $verbose;
    my $help;
    my $line;
    my $line_prefix = '';
    my @matchers = ();

    die "Error while getting options!" unless GetOptions(
        'line|l'           =>  \$line,
        'prefix|p=s'       =>  \$line_prefix,
        'match|m=s'        =>  sub  {  push  @matchers,  [  'm',  qr{$_[1]}i  ]  },
        'skip|s=s'         =>  sub  {  push  @matchers,  [  's',  qr{$_[1]}i  ]  },
        'case-match|M=s'   =>  sub  {  push  @matchers,  [  'm',  qr{$_[1]}  ]  },
        'case-skip|S=s'    =>  sub  {  push  @matchers,  [  's',  qr{$_[1]}  ]  },
        'help|h|?'         =>  \$help,
    );

    $self->show_help_and_die() if $help;
    die "No matchers defined!" if 0 == scalar @matchers;
    unshift @matchers, [ 'm', qr{.} ] if 's' eq $matchers[0]->[0];

    $self->{'matchers'} = \@matchers;
    $self->{'line'} = $line;
    $self->{'line_prefix'} = $self->prefix_to_re( $line_prefix );
    return;
}

sub prefix_to_re {
    my $self = shift;
    my $prefix = shift;

    my %re = (
        'u' => '(?:[a-z0-9_]*|\[unknown\])',
        'd' => '(?:[a-z0-9_]*|\[unknown\])',
        'r' => '(?:\d{1,3}(?:\.\d{1,3}){3}\(\d+\)|\[local\])?',
        'h' => '\d{1,3}(?:\.\d{1,3}){3}|\[local\]',
        'p' => '\d+',
        't' => '\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d (?:[A-Z]+|\+\d\d\d\d)',
        'm' => '\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d\.\d+ (?:[A-Z]+|\+\d\d\d\d)',
        'l' => '\d+',
        'i' => '(?:BEGIN|COMMIT|DELETE|INSERT|ROLLBACK|SELECT|SET|SHOW|UPDATE)',
        'x' => '\d+',
        'c' => '[a-f0-9]+\.[a-f0-9]+',
    );

    my @known_keys = keys %re;
    my $known_re = join '|', @known_keys;

    $prefix =~ s/([()\[\]])/\\$1/g;
    $prefix =~ s/%($known_re)/$re{$1}/g;
    return qr{$prefix};
}

sub show_help_and_die {
    my $self = shift;
    print <<_EOHELP_;
Syntax:
    ... | $PROGRAM_NAME [-m ...] [-s ...] [-p ...]

Options:
    --line        (-l) - print just matching "line" (see below)
    --prefix      (-p) - exact value of log_line_prefix from PostgreSQL
    --match       (-m) - regular expression that has to match to print given line
    --skip        (-s) - regular expression that will cause line to be skipped
    --case-match  (-M) - case sensitive --match
    --case-skip   (-S) - case sensitive --skip

You can provide many -m -s options, which will then function as filtering chain.
If first (from -m/-s/-M/-S) is -s/-S, then matching chain is prepended with "-m ."

For example:
    cat pg.log | $PROGRAM_NAME -m LOG: -s pg_catalog -m depesz

will print those lines that contain LOG:. If such line contains pg_catalog,
it will be skipped, unless it contains depesz - in which case it will be
printed anyway.

Line:
$PROGRAM_NAME will concatenate all physical lines that make one logical line
(for example in case of multi-line PG query). Some log lines contain
additional lines (HINT:, DETAIL:, CONTEXT: and so on).
If --line is passed - every line is assumed to be on it's own - so you can
get single "CONTEXT:" line as output. If --line is not used, those auxiliary
lines will be always outputted together with the line that caused them to be
shown.
_EOHELP_
   exit(1);
}

