#define PERL_CORE 1   /* required in order to get working SAVEHINTS() */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#define PERL_VERSION_DECIMAL(r,v,s) (r*1000000 + v*1000 + s)
#define PERL_DECIMAL_VERSION \
	PERL_VERSION_DECIMAL(PERL_REVISION,PERL_VERSION,PERL_SUBVERSION)
#define PERL_VERSION_GE(r,v,s) \
	(PERL_DECIMAL_VERSION >= PERL_VERSION_DECIMAL(r,v,s))

#if !PERL_VERSION_GE(5,11,0)

#define refcounted_he_free(he) Perl_refcounted_he_free(aTHX_ he)

static OP *pp_squashhints(pTHX)
{
	SAVEHINTS();
	hv_clear(GvHV(PL_hintgv));
# if PERL_VERSION_GE(5,9,4)
	if(PL_compiling.cop_hints_hash) {
		refcounted_he_free(PL_compiling.cop_hints_hash);
		PL_compiling.cop_hints_hash = NULL;
	}
# endif /* >=5.9.4 */
	return PL_op->op_next;
}

#define gen_squashhints_op() THX_gen_squashhints_op(aTHX)
static OP *THX_gen_squashhints_op(pTHX)
{
	OP *squashhints_op = newOP(OP_PUSHMARK, 0);
	squashhints_op->op_type = OP_RAND;
	squashhints_op->op_ppaddr = pp_squashhints;
	return squashhints_op;
}

static OP *(*nxck_require)(pTHX_ OP *op);

static OP *myck_require(pTHX_ OP *op)
{
	op = nxck_require(aTHX_ op);
	op = append_list(OP_LINESEQ, (LISTOP*)gen_squashhints_op(),
					(LISTOP*)op);
	op = prepend_elem(OP_LINESEQ, newOP(OP_ENTER, 0), op);
	op->op_type = OP_LEAVE;
	op->op_ppaddr = PL_ppaddr[OP_LEAVE];
	op->op_flags |= OPf_PARENS;
	return op;
}

#endif /* <5.11.0 */

MODULE = Lexical::SealRequireHints PACKAGE = Lexical::SealRequireHints

void
import(SV *classname)
CODE:
#if !PERL_VERSION_GE(5,11,0)
	if(!nxck_require) {
		nxck_require = PL_check[OP_REQUIRE];
		PL_check[OP_REQUIRE] = myck_require;
	}
#endif /* <5.11.0 */

void
unimport(SV *classname, ...)
CODE:
	Perl_croak(aTHX_
		"Lexical::SealRequireHints does not support unimportation");
