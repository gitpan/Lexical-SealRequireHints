=head1 NAME

Lexical::SealRequireHints - prevent leakage of lexical hints

=head1 SYNOPSIS

	use Lexical::SealRequireHints;

=head1 DESCRIPTION

There is a bug in Perl's handling of the C<%^H> (lexical hints) variable
that causes lexical state in one file to leak into another that is
C<require>d/C<use>d from it.  This bug will probably be fixed in Perl
5.10.2, and is definitely fixed in Perl 5.11.0, but in any earlier
version it is necessary to work around it.  On versions of Perl that
require a fix, this module globally changes the behaviour of C<require>
and C<use> so that they no longer exhibit the bug.  This is the most
convenient kind of workaround, and is meant to be invoked by modules
that make use of lexical state.

The workaround supplied by this module takes effect the first time its
C<import> method is called.  Typically this will be done by means of
a C<use> statement.  This should be done before putting anything into
C<%^H> that would have a problem with leakage; usually it suffices to
do this when loading the module that supplies the mechanism to set up
the vulnerable lexical state.  Invoking this module multiple times,
from multiple lexical-related modules, is not a problem: the workaround
is only applied once, and applies to everything.

This module is implemented in XS, with a pure Perl backup version for
systems that can't handle XS modules.  The XS version has a better chance
of playing nicely with other modules that modify C<require> handling.

=cut

package Lexical::SealRequireHints;

{ use 5.006; }
use warnings;
use strict;

our $VERSION = "0.004";

if(eval { local $SIG{__DIE__};
	require XSLoader;
	XSLoader::load(__PACKAGE__, $VERSION);
	1;
}) {
	# successfully loaded XS, nothing else to do
} elsif("$]" >= 5.011) {
	# bug not present
	*import = sub {
		die "$_[0] does not take any importation arguments\n"
			unless @_ == 1;
	};
	*unimport = sub { die "$_[0] does not support unimportation\n" };
} elsif("$]" >= 5.008) {
	my $done;
	*import = sub {
		die "$_[0] does not take any importation arguments\n"
			unless @_ == 1;
		return if $done;
		$done = 1;
		our $next_require = defined(&CORE::GLOBAL::require) ?
			\&CORE::GLOBAL::require : sub {
				my($arg) = @_;
				# The shenanigans with $CORE::GLOBAL::{require}
				# are required because if there's a
				# &CORE::GLOBAL::require when the eval is
				# executed then the CORE::require in there is
				# interpreted as plain require on some Perl
				# versions, leading to recursion.
				my $grequire = $CORE::GLOBAL::{require};
				delete $CORE::GLOBAL::{require};
				my $result = eval q{
					local $SIG{__DIE__};
					$CORE::GLOBAL::{require} = $grequire;
					package }.caller(0).q{;
					CORE::require($arg);
				};
				die $@ if $@ ne "";
				return $result;
			};
		no warnings "redefine";
		*CORE::GLOBAL::require = sub {
			die "wrong number of arguments to require\n"
				unless @_ == 1;
			my($arg) = @_;
			my $result = eval q{
				local $SIG{__DIE__};
				package }.caller(0).q{;
				delete $^H{$_}
					foreach keys(%^H), qw($[ open< open>);
				$next_require->($arg);
			};
			die $@ if $@ ne "";
			return $result;
		};
	};
	*unimport = sub { die "$_[0] does not support unimportation\n" };
} else {
	die "pure Perl version of @{[__PACKAGE__]} can't work on pre-5.8 perl";
}

=head1 BUGS

The operation of this module depends on influencing the compilation of
C<require>.  As a result, it cannot prevent lexical state leakage through
a C<require> statement that was compiled before this module was invoked.
This is not a problem when lexical state is managed in the usual ways:
the leakage that is a problem is almost always through C<use> statements,
which are executed immediately after they are compiled.  The situations
that would escape the sealant of this module are rather convoluted.
If such a problem does occur, a workaround is to invoke this module
earlier.

This module applies its workaround on any version of Perl prior to 5.11.0.
It is likely that a later version in the 5.10 series, probably 5.10.2,
will incorporate a fix for the leakage bug, backported from 5.11.  In that
case, this module's workaround would be used redundantly on such later
5.10 versions.  This shouldn't make lexical things behave any worse,
but it would mean unnecessarily incurring the slight downsides of having
the workaround in place.  When such a Perl version is released, this
module will be updated to detect it and avoid unnecessarily applying
the workaround.

=head1 SEE ALSO

L<perlpragma>

=head1 AUTHOR

Andrew Main (Zefram) <zefram@fysh.org>

=head1 COPYRIGHT

Copyright (C) 2009, 2010 Andrew Main (Zefram) <zefram@fysh.org>

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
