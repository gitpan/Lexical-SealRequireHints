=head1 NAME

Lexical::SealRequireHints - prevent leakage of lexical hints

=head1 SYNOPSIS

	use Lexical::SealRequireHints;

=head1 DESCRIPTION

This module works around two historical bugs in Perl's handling of the
C<%^H> (lexical hints) variable.  One bug causes lexical state in one file
to leak into another that is C<require>d/C<use>d from it.  This bug, [perl
#68590], was present up to Perl 5.10, fixed in Perl 5.11.0.  The second
bug causes lexical state (normally a blank C<%^H> once the first bug is
fixed) to leak outwards from C<utf8.pm>, if it is automatically loaded
during Unicode regular expression matching, into whatever source is
compiling at the time of the regexp match.  This bug, [perl #73174],
was present from Perl 5.8.7 up to Perl 5.11.5, fixed in Perl 5.12.0.

Both of these bugs seriously damage the usability of any module
relying on C<%^H> for lexical scoping, on the affected Perl versions.
It is in practice essential for such modules to work around these bugs.
On versions of Perl that require such a workaround, this module globally
changes the behaviour of C<require>, including C<use> and the implicit
C<require> performed in Unicode regular expression matching, so that
it no longer exhibits these bugs.  This is the most convenient kind of
workaround, and is meant to be invoked by any module that makes use of
lexical state.

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

{ use 5.006001; }
# Don't "use warnings" here because warnings.pm can include require
# statements that execute at runtime, and if they're compiled before
# this module takes effect then they won't get the magic needed to avoid
# leaking hints generated later.

our $VERSION = "0.006";

if("$]" >= 5.012) {
	# bug not present
	*import = sub {
		die "$_[0] does not take any importation arguments\n"
			unless @_ == 1;
	};
	*unimport = sub { die "$_[0] does not support unimportation\n" };
} elsif(eval { local $SIG{__DIE__};
	require XSLoader;
	XSLoader::load(__PACKAGE__, $VERSION);
	1;
}) {
	# Successfully loaded XS.  Now preemptively load modules that
	# may be subject to delayed require statements in XSLoader or
	# things that it loaded.
	foreach(qw(Carp.pm Carp/Heavy.pm)) {
		eval { local $SIG{__DIE__}; require($_); };
	}
} elsif("$]" >= 5.008) {
	my $done;
	*import = sub {
		die "$_[0] does not take any importation arguments\n"
			unless @_ == 1;
		return if $done;
		$done = 1;
		# $next_require empirically doesn't work as a my variable.
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
		# Need to suppress the redefinition warning, without
		# invoking warnings.pm.
		BEGIN { ${^WARNING_BITS} = ""; }
		*CORE::GLOBAL::require = sub {
			die "wrong number of arguments to require\n"
				unless @_ == 1;
			my($arg) = @_;
			# %^H gets localised (in the magic way it
			# requires) by the string eval, provided that the
			# HINT_LOCALIZE_HH bit is set.	Normally that
			# bit would be set if there were anything in
			# %^H, but when affected by [perl #73174] the
			# core's swash-loading code locally clears $^H
			# without changing %^H, so we set the bit here.
			# We localise $^H while doing this, in order to
			# not clobber $^H across a normal require where
			# the bit is legitimately clear, except on Perl
			# 5.11, where the bit needs to stay set in order
			# to get proper restoration of %^H.
			local $^H = $^H | 0x20000 if "$]" < 5.011;
			$^H |= 0x20000;
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

=head1 SEE ALSO

L<perlpragma>

=head1 AUTHOR

Andrew Main (Zefram) <zefram@fysh.org>

=head1 COPYRIGHT

Copyright (C) 2009, 2010, 2011 Andrew Main (Zefram) <zefram@fysh.org>

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
