''	FreeBASIC - 32-bit BASIC Compiler.
''	Copyright (C) 2004-2006 Andre Victor T. Vicentini (av1ctor@yahoo.com.br)
''
''	This program is free software; you can redistribute it and/or modify
''	it under the terms of the GNU General Public License as published by
''	the Free Software Foundation; either version 2 of the License, or
''	(at your option) any later version.
''
''	This program is distributed in the hope that it will be useful,
''	but WITHOUT ANY WARRANTY; without even the implied warranty of
''	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
''	GNU General Public License for more details.
''
''	You should have received a copy of the GNU General Public License
''	along with this program; if not, write to the Free Software
''	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA.


'' [A]bstract [S]yntax [T]ree core
''
'' obs: 1) each AST only stores a single expression and its atoms (inc. arrays and functions)
''      2) after the AST is optimized (constants folding, arithmetic associations, etc),
''         its sent to IR, where the expression becomes three-address-codes
''		3) AST optimizations don't include common-sub-expression/dead-code elimination,
''         that must be done by the DAG module
''
'' chng: sep/2004 written [v1ctor]


#include once "inc\fb.bi"
#include once "inc\fbint.bi"
#include once "inc\list.bi"
#include once "inc\emit.bi"
#include once "inc\ir.bi"
#include once "inc\rtl.bi"
#include once "inc\ast.bi"


declare sub 		astProcListInit		( )

declare sub 		astProcListEnd		( )

declare function 	astLoadNOP			( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadASSIGN		( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadCONV			( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadBOP			( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadUOP			( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadCONST		( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadVAR			( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadIDX			( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadPTR			( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadCALL			( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadCALLCTOR		( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadADDR			( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadLOAD			( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadBRANCH		( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadIIF			( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadOFFSET		( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadLINK			( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadSTACK		( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadENUM			( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadLABEL		( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadLIT			( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadASM			( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadJMPTB		( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadDBG			( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadMEM			( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadBOUNDCHK		( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadPTRCHK		( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadFIELD		( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadSCOPEBEGIN	( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadSCOPEEND		( byval n as ASTNODE ptr ) as IRVREG ptr

declare function 	astLoadDECL			( byval n as ASTNODE ptr ) as IRVREG ptr

'' globals
	dim shared as ASTCTX ast

	'' same order as AST_NODECLASS
	dim shared ast_classTB( 0 to AST_CLASSES-1 ) as AST_CLASSINFO => _
	{ _
		( @astLoadNOP			, FALSE			), _	'' AST_NODECLASS_NOP
		( @astLoadLOAD			, TRUE			), _	'' AST_NODECLASS_LOAD
		( @astLoadASSIGN		, TRUE			), _	'' AST_NODECLASS_ASSIGN
		( @astLoadBOP			, TRUE			), _	'' AST_NODECLASS_BOP
		( @astLoadUOP			, TRUE			), _	'' AST_NODECLASS_UOP
		( @astLoadCONV			, TRUE			), _	'' AST_NODECLASS_CONV
		( @astLoadADDR			, TRUE			), _	'' AST_NODECLASS_ADDR
		( @astLoadBRANCH		, TRUE			), _	'' AST_NODECLASS_BRANCH
		( @astLoadCALL			, TRUE			), _	'' AST_NODECLASS_CALL
		( @astLoadCALLCTOR		, TRUE			), _	'' AST_NODECLASS_CALLCTOR
		( @astLoadSTACK			, TRUE			), _	'' AST_NODECLASS_STACK
		( @astLoadMEM			, TRUE			), _	'' AST_NODECLASS_MEM
		( @astLoadNOP			, FALSE			), _	'' AST_NODECLASS_COMP
		( @astLoadLINK			, FALSE			), _	'' AST_NODECLASS_LINK
		( @astLoadCONST			, FALSE			), _	'' AST_NODECLASS_CONST
		( @astLoadVAR			, TRUE			), _	'' AST_NODECLASS_VAR
		( @astLoadIDX			, TRUE			), _	'' AST_NODECLASS_IDX
		( @astLoadFIELD			, TRUE			), _	'' AST_NODECLASS_FIELD
		( @astLoadENUM			, FALSE			), _	'' AST_NODECLASS_ENUM
		( @astLoadPTR			, TRUE			), _	'' AST_NODECLASS_PTR
		( @astLoadLABEL			, FALSE			), _	'' AST_NODECLASS_LABEL
		( @astLoadNOP			, TRUE			), _	'' AST_NODECLASS_ARG
		( @astLoadOFFSET		, FALSE			), _	'' AST_NODECLASS_OFFSET
		( @astLoadDECL			, FALSE			), _	'' AST_NODECLASS_DECL
		( @astLoadIIF			, TRUE			), _	'' AST_NODECLASS_IIF
		( @astLoadLIT			, FALSE			), _	'' AST_NODECLASS_LIT
		( @astLoadASM			, TRUE			), _	'' AST_NODECLASS_ASM
		( @astLoadJMPTB			, TRUE			), _	'' AST_NODECLASS_JMPTB
		( @astLoadDBG			, FALSE			), _	'' AST_NODECLASS_DBG
		( @astLoadBOUNDCHK		, TRUE			), _	'' AST_NODECLASS_BOUNDCHK
		( @astLoadPTRCHK		, TRUE			), _	'' AST_NODECLASS_PTRCHK
		( @astLoadSCOPEBEGIN	, TRUE			), _	'' AST_NODECLASS_SCOPEBEGIN
		( @astLoadSCOPEEND		, TRUE			), _	'' AST_NODECLASS_SCOPEEND
		( @astLoadNOP			, TRUE			), _	'' AST_NODECLASS_SCOPE_BREAK
		( @astLoadNOP			, TRUE			), _	'' AST_NODECLASS_TYPEINI
		( @astLoadNOP			, TRUE			), _	'' AST_NODECLASS_TYPEINI_PAD
		( @astLoadNOP			, TRUE			), _	'' AST_NODECLASS_TYPEINI_ASSIGN
		( @astLoadNOP			, TRUE			), _	'' AST_NODECLASS_TYPEINI_CTORCALL
		( @astLoadNOP			, TRUE			), _	'' AST_NODECLASS_TYPEINI_CTORLIST
		( @astLoadNOP			, TRUE			), _	'' AST_NODECLASS_PROC
		( @astLoadNOP			, FALSE			) _		'' AST_NODECLASS_NAMESPC
	}

	'' same order as AST_OP
	dim shared ast_opTB( 0 to AST_OPCODES-1 ) as AST_OPINFO => _
	{ _
		( AST_NODECLASS_LOAD	, AST_OPFLAGS_NONE ), _ '' AST_OP_LOAD
		( AST_NODECLASS_LOAD	, AST_OPFLAGS_NONE ), _ '' AST_OP_LOADRES
		( AST_NODECLASS_ASSIGN	, AST_OPFLAGS_NONE ), _	'' AST_OP_ASSIGN
		( AST_NODECLASS_ASSIGN	, AST_OPFLAGS_NONE ), _	'' AST_OP_SPILLREGS
		( AST_NODECLASS_BOP		, AST_OPFLAGS_COMM ), _	'' AST_OP_ADD
		( AST_NODECLASS_BOP		, AST_OPFLAGS_SELF ), _	'' AST_OP_ADD_SELF
		( AST_NODECLASS_BOP		, AST_OPFLAGS_NONE ), _	'' AST_OP_SUB
		( AST_NODECLASS_BOP		, AST_OPFLAGS_SELF ), _	'' AST_OP_SUB_SELF
		( AST_NODECLASS_BOP		, AST_OPFLAGS_COMM ), _	'' AST_OP_MUL
		( AST_NODECLASS_BOP		, AST_OPFLAGS_SELF ), _	'' AST_OP_MUL_SELF
		( AST_NODECLASS_BOP		, AST_OPFLAGS_NONE ), _	'' AST_OP_DIV
		( AST_NODECLASS_BOP		, AST_OPFLAGS_SELF ), _	'' AST_OP_DIV_SELF
		( AST_NODECLASS_BOP		, AST_OPFLAGS_NONE ), _	'' AST_OP_INTDIV
		( AST_NODECLASS_BOP		, AST_OPFLAGS_SELF ), _	'' AST_OP_INTDIV_SELF
		( AST_NODECLASS_BOP		, AST_OPFLAGS_NONE ), _	'' AST_OP_MOD
		( AST_NODECLASS_BOP		, AST_OPFLAGS_SELF ), _	'' AST_OP_MOD_SELF
		( AST_NODECLASS_BOP		, AST_OPFLAGS_COMM ), _	'' AST_OP_AND
		( AST_NODECLASS_BOP		, AST_OPFLAGS_SELF ), _	'' AST_OP_AND_SELF
		( AST_NODECLASS_BOP		, AST_OPFLAGS_COMM ), _	'' AST_OP_OR
		( AST_NODECLASS_BOP		, AST_OPFLAGS_SELF ), _	'' AST_OP_OR_SELF
		( AST_NODECLASS_BOP		, AST_OPFLAGS_COMM ), _	'' AST_OP_XOR
		( AST_NODECLASS_BOP		, AST_OPFLAGS_SELF ), _	'' AST_OP_XOR_SELF
		( AST_NODECLASS_BOP		, AST_OPFLAGS_NONE ), _	'' AST_OP_EQV
		( AST_NODECLASS_BOP		, AST_OPFLAGS_SELF ), _	'' AST_OP_EQV_SELF
		( AST_NODECLASS_BOP		, AST_OPFLAGS_NONE ), _	'' AST_OP_IMP
		( AST_NODECLASS_BOP		, AST_OPFLAGS_SELF ), _	'' AST_OP_IMP_SELF
		( AST_NODECLASS_BOP		, AST_OPFLAGS_NONE ), _	'' AST_OP_SHL
		( AST_NODECLASS_BOP		, AST_OPFLAGS_SELF ), _	'' AST_OP_SHL_SELF
		( AST_NODECLASS_BOP		, AST_OPFLAGS_NONE ), _	'' AST_OP_SHR
		( AST_NODECLASS_BOP		, AST_OPFLAGS_SELF ), _	'' AST_OP_SHR_SELF
		( AST_NODECLASS_BOP		, AST_OPFLAGS_NONE ), _	'' AST_OP_POW
		( AST_NODECLASS_BOP		, AST_OPFLAGS_SELF ), _	'' AST_OP_POW_SELF
		( AST_NODECLASS_COMP	, AST_OPFLAGS_COMM ), _	'' AST_OP_EQ
		( AST_NODECLASS_COMP	, AST_OPFLAGS_NONE ), _	'' AST_OP_GT
		( AST_NODECLASS_COMP	, AST_OPFLAGS_NONE ), _	'' AST_OP_LT
		( AST_NODECLASS_COMP	, AST_OPFLAGS_COMM ), _	'' AST_OP_NE
		( AST_NODECLASS_COMP	, AST_OPFLAGS_NONE ), _	'' AST_OP_GE
		( AST_NODECLASS_COMP	, AST_OPFLAGS_NONE ), _	'' AST_OP_LE
		( AST_NODECLASS_UOP 	, AST_OPFLAGS_NONE ), _	'' AST_OP_NOT
		( AST_NODECLASS_UOP		, AST_OPFLAGS_NONE ), _	'' AST_OP_PLUS
		( AST_NODECLASS_UOP		, AST_OPFLAGS_NONE ), _	'' AST_OP_NEG
		( AST_NODECLASS_UOP		, AST_OPFLAGS_NONE ), _	'' AST_OP_ABS
		( AST_NODECLASS_UOP		, AST_OPFLAGS_NONE ), _	'' AST_OP_SGN
		( AST_NODECLASS_UOP		, AST_OPFLAGS_NONE ), _	'' AST_OP_SIN
		( AST_NODECLASS_UOP		, AST_OPFLAGS_NONE ), _	'' AST_OP_ASIN
		( AST_NODECLASS_UOP		, AST_OPFLAGS_NONE ), _	'' AST_OP_COS
		( AST_NODECLASS_UOP		, AST_OPFLAGS_NONE ), _	'' AST_OP_ACOS
		( AST_NODECLASS_UOP		, AST_OPFLAGS_NONE ), _	'' AST_OP_TAN
		( AST_NODECLASS_UOP		, AST_OPFLAGS_NONE ), _	'' AST_OP_ATAN
		( AST_NODECLASS_BOP		, AST_OPFLAGS_NONE ), _	'' AST_OP_ATN2
		( AST_NODECLASS_UOP		, AST_OPFLAGS_NONE ), _	'' AST_OP_SQRT
		( AST_NODECLASS_UOP		, AST_OPFLAGS_NONE ), _	'' AST_OP_LOG
		( AST_NODECLASS_UOP		, AST_OPFLAGS_NONE ), _	'' AST_OP_FLOOR
		( AST_NODECLASS_ADDR	, AST_OPFLAGS_NONE ), _	'' AST_OP_ADDROF
		( AST_NODECLASS_ADDR 	, AST_OPFLAGS_NONE ), _	'' AST_OP_DEREF
		( AST_NODECLASS_CONV 	, AST_OPFLAGS_NONE ), _	'' AST_OP_CAST
		( AST_NODECLASS_CONV	, AST_OPFLAGS_NONE ), _	'' AST_OP_TOINT
		( AST_NODECLASS_CONV	, AST_OPFLAGS_NONE ), _	'' AST_OP_TOFLT
		( AST_NODECLASS_STACK	, AST_OPFLAGS_NONE ), _	'' AST_OP_PUSH
		( AST_NODECLASS_STACK	, AST_OPFLAGS_NONE ), _	'' AST_OP_POP
		( AST_NODECLASS_STACK	, AST_OPFLAGS_NONE ), _	'' AST_OP_PUSHUDT
		( AST_NODECLASS_STACK	, AST_OPFLAGS_NONE ), _	'' AST_OP_STACKALIGN
		( AST_NODECLASS_BRANCH	, AST_OPFLAGS_NONE ), _	'' AST_OP_JEQ
		( AST_NODECLASS_BRANCH	, AST_OPFLAGS_NONE ), _	'' AST_OP_JGT
		( AST_NODECLASS_BRANCH	, AST_OPFLAGS_NONE ), _	'' AST_OP_JLT
		( AST_NODECLASS_BRANCH	, AST_OPFLAGS_NONE ), _	'' AST_OP_JNE
		( AST_NODECLASS_BRANCH	, AST_OPFLAGS_NONE ), _	'' AST_OP_JGE
		( AST_NODECLASS_BRANCH	, AST_OPFLAGS_NONE ), _	'' AST_OP_JLE
		( AST_NODECLASS_BRANCH	, AST_OPFLAGS_NONE ), _	'' AST_OP_JMP
		( AST_NODECLASS_BRANCH	, AST_OPFLAGS_NONE ), _	'' AST_OP_CALL
		( AST_NODECLASS_BRANCH	, AST_OPFLAGS_NONE ), _	'' AST_OP_LABEL
		( AST_NODECLASS_BRANCH	, AST_OPFLAGS_NONE ), _	'' AST_OP_RET
		( AST_NODECLASS_CALL	, AST_OPFLAGS_NONE ), _	'' AST_OP_CALLFUNC
		( AST_NODECLASS_CALL	, AST_OPFLAGS_NONE ), _	'' AST_OP_CALLPTR
		( AST_NODECLASS_CALL	, AST_OPFLAGS_NONE ), _	'' AST_OP_JUMPPTR
		( AST_NODECLASS_MEM		, AST_OPFLAGS_NONE ), _	'' AST_OP_MEMMOVE
		( AST_NODECLASS_MEM		, AST_OPFLAGS_NONE ), _	'' AST_OP_MEMSWAP
		( AST_NODECLASS_MEM		, AST_OPFLAGS_NONE ), _	'' AST_OP_MEMCLEAR
		( AST_NODECLASS_MEM		, AST_OPFLAGS_NONE ) _	'' AST_OP_STKCLEAR
	}

	dim shared as uinteger ast_bitmaskTB( 0 to 32 ) = _
	{ _
		0, _
		1, 3, 7, 15, 31, 63, 127, 255, _
		511, 1023, 2047, 4095, 8191, 16383, 32767, 65565, _
        131071, 262143, 524287, 1048575, 2097151, 4194303, 8388607, 16777215, _
        33554431, 67108863, 134217727, 268435455, 536870911, 1073741823, 2147483647, 4294967295 _
	}

	dim shared as longint ast_minlimitTB( FB_DATATYPE_BYTE to FB_DATATYPE_ULONGINT ) = _
	{ _
		-128LL, _								'' byte
		0LL, _                                  '' ubyte
		0LL, _                                  '' char
		-32768LL, _                             '' short
		0LL, _                                  '' ushort
		0LL, _                                  '' wchar
		-2147483648LL, _                        '' int
		0LL, _                                  '' uint
		-2147483648LL, _                        '' enum
		0LL, _                                  '' bitfield
		-9223372036854775808LL, _               '' longint
		0LL _                                   '' ulongint
	}

	dim shared as ulongint ast_maxlimitTB( FB_DATATYPE_BYTE to FB_DATATYPE_ULONGINT ) = _
	{ _
		127ULL, _                               '' ubyte
		255ULL, _                               '' byte
		255ULL, _                               '' char
		32767ULL, _                             '' short
		65535ULL, _                             '' ushort
		65535ULL, _                             '' wchar
		2147483647ULL, _                        '' int
		4294967295ULL, _                        '' uint
		2147483647ULL, _                        '' enum
		4294967295ULL, _                        '' bitfield
		9223372036854775807ULL, _               '' longint
		18446744073709551615ULL _               '' ulongint
	}


'':::::
private sub hInitTempLists

	listNew( @ast.tempstr, AST_INITTEMPSTRINGS, len( ASTTEMPSTR ), LIST_FLAGS_NOCLEAR )

end sub

'':::::
private sub hEndTempLists

	listFree( @ast.tempstr )

end sub

'':::::
sub astInit static

	''
    listNew( @ast.astTB, AST_INITNODES, len( ASTNODE ), LIST_FLAGS_NOCLEAR )

    ''
    hInitTempLists( )

    ast.doemit = TRUE
    ast.isopt = FALSE
    ast.typeinicnt = 0
    ast.currblock = NULL

	'' wchar len depends on the target platform
	ast_minlimitTB(FB_DATATYPE_WCHAR) = ast_minlimitTB(env.target.wchar.type)
	ast_maxlimitTB(FB_DATATYPE_WCHAR) = ast_maxlimitTB(env.target.wchar.type)

    ''
    astProcListInit( )

end sub

'':::::
sub astEnd static

	''
	hEndTempLists( )

	''
	astProcListEnd( )

	''
	listFree( @ast.astTB )

end sub

'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
'' node type update
'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

'':::::
function astUpdStrConcat _
	( _
		byval n as ASTNODE ptr _
	) as ASTNODE ptr

	static as ASTNODE ptr l, r

	function = n

	if( n = NULL ) then
		exit function
	end if

	'' this proc will be called for each function param, same
	'' with assignment -- assuming here that IIF won't
	'' support strings
	select case n->dtype
	case FB_DATATYPE_STRING, FB_DATATYPE_FIXSTR, _
		 FB_DATATYPE_WCHAR

	case else
		exit function
	end select

	'' walk
	l = n->l
	if( l <> NULL ) then
		n->l = astUpdStrConcat( l )
	end if

	r = n->r
	if( r <> NULL ) then
		n->r = astUpdStrConcat( r )
	end if

	'' convert "string + string" to "StrConcat( string, string )"
	if( n->class = AST_NODECLASS_BOP ) then
		if( n->op.op = AST_OP_ADD ) then
			l = n->l
			r = n->r
			if( n->dtype <> FB_DATATYPE_WCHAR ) then
				function = rtlStrConcat( l, l->dtype, r, r->dtype )
			else
				function = rtlWstrConcat( l, l->dtype, r, r->dtype )
			end if
			astDelNode( n )
		end if
	end if

end function

'':::::
function astUpdComp2Branch _
	( _
		byval n as ASTNODE ptr, _
		byval label as FBSYMBOL ptr, _
		byval isinverse as integer _
	) as ASTNODE ptr

	dim as integer op = any
	dim as ASTNODE ptr l = any, expr = any
	static as integer dtype, istrue

	if( n = NULL ) then
		return NULL
	end if

	dtype = n->dtype

	'' string? invalid..
	if( symbGetDataClass( dtype ) = FB_DATACLASS_STRING ) then
		return NULL
	end if

    '' CHAR and WCHAR literals are also from the INTEGER class
    select case dtype
    case FB_DATATYPE_CHAR, FB_DATATYPE_WCHAR
    	'' don't allow, unless it's a deref pointer
    	if( astIsPTR( n ) = FALSE ) then
    		return NULL
    	end if

	'' UDT?
	case FB_DATATYPE_STRUCT
		return NULL
	end select

	'' shortcut "exp logop exp" if it's at top of tree (used to optimize IF/ELSEIF/WHILE/UNTIL)
	if( n->class <> AST_NODECLASS_BOP ) then
#if 0
		'' UOP? check if it's a NOT
		if( n->class = AST_NODECLASS_UOP ) then
			if( n->op.op = AST_OP_NOT ) then
				l = astUpdComp2Branch( n->l, label, isinverse = FALSE )
				astDelNode( n )
				return l
			end if
		end if
#endif

		'' CONST?
		if( n->defined ) then
			if( isinverse = FALSE ) then
				'' branch if false
				select case as const dtype
				case FB_DATATYPE_LONGINT, FB_DATATYPE_ULONGINT
					istrue = n->con.val.long = 0
				case FB_DATATYPE_SINGLE, FB_DATATYPE_DOUBLE
					istrue = n->con.val.float = 0
				case else
					istrue = n->con.val.int = 0
				end select

				if( istrue ) then
					astDelNode( n )
					n = astNewBRANCH( AST_OP_JMP, label, NULL )
					if( n = NULL ) then
						return NULL
					end if
				end if
			else
				'' branch if true
				select case as const dtype
				case FB_DATATYPE_LONGINT, FB_DATATYPE_ULONGINT
					istrue = n->con.val.long <> 0
				case FB_DATATYPE_SINGLE, FB_DATATYPE_DOUBLE
					istrue = n->con.val.float <> 0
				case else
					istrue = n->con.val.int <> 0
				end select

				if( istrue ) then
					astDelNode( n )
					n = astNewBRANCH( AST_OP_JMP, label, NULL )
					if( n = NULL ) then
						return NULL
					end if
				end if
			end if

		else
			'' otherwise, check if zero (ie= FALSE)
			if( isinverse = FALSE ) then
				op = AST_OP_EQ
			else
				op = AST_OP_NE
			end if

			'' zstring? astNewBOP will think both are zstrings..
			select case dtype
			case FB_DATATYPE_CHAR
				dtype = FB_DATATYPE_UINT
			case FB_DATATYPE_WCHAR
				dtype = env.target.wchar.type
			end select

			select case as const dtype
			case FB_DATATYPE_LONGINT, FB_DATATYPE_ULONGINT
				expr = astNewCONSTl( 0, dtype )
			case FB_DATATYPE_SINGLE, FB_DATATYPE_DOUBLE
				expr = astNewCONSTf( 0.0, dtype )
			case else
				expr = astNewCONSTi( 0, dtype )
			end select

			n = astNewBOP( op, n, expr, label, AST_OPOPT_NONE )

			if( n = NULL ) then
				return NULL
			end if
		end if

		'' exit
		return n
	end if

	''
	op 	  = n->op.op

	'' relational operator?
	select case as const op
	case AST_OP_EQ, AST_OP_NE, AST_OP_GT, AST_OP_LT, AST_OP_GE, AST_OP_LE

		'' invert it
		if( isinverse = FALSE ) then
			n->op.op = astGetInverseLogOp( op )
		end if

		'' tell IR that the destine label is already set
		n->op.ex = label

		return n

	'' binary op that sets the flags? (x86 opt, may work on some RISC cpu's)
	case AST_OP_ADD, AST_OP_SUB, AST_OP_SHL, AST_OP_SHR, _
		 AST_OP_AND, AST_OP_OR, AST_OP_XOR, AST_OP_IMP
		 ', AST_OP_EQV -- NOT doesn't set any flags, so EQV can't be optimized (x86 assumption)

		'' x86-quirk: only if integers, as FPU will set its own flags, that must copied back
		if( symbGetDataClass( dtype ) = FB_DATACLASS_INTEGER ) then
            '' can't be done with longints either, as flag is set twice
            if( (dtype <> FB_DATATYPE_LONGINT) and (dtype <> FB_DATATYPE_ULONGINT) ) then

				'' check if zero (ie= FALSE)
				if( isinverse = FALSE ) then
					op = AST_OP_JEQ
				else
					op = AST_OP_JNE
				end if

				return astNewBRANCH( op, label, n )
			end if
		end if

	end select

	'' if no optimization could be done, check if zero (ie= FALSE)
	if( isinverse = FALSE ) then
		op = AST_OP_EQ
	else
		op = AST_OP_NE
	end if

	select case as const dtype
	case FB_DATATYPE_LONGINT, FB_DATATYPE_ULONGINT
		expr = astNewCONSTl( 0, dtype )
	case FB_DATATYPE_SINGLE, FB_DATATYPE_DOUBLE
		expr = astNewCONSTf( 0.0, dtype )
	case else
		expr = astNewCONSTi( 0, dtype )
	end select

	function = astNewBOP( op, n, expr, label, AST_OPOPT_NONE )

end function

'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
'' misc
'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

'':::::
function astPtrCheck _
	( _
		byval pdtype as integer, _
		byval psubtype as FBSYMBOL ptr, _
		byval expr as ASTNODE ptr _
	) as integer static

	dim as integer edtype, pdtype_np, edtype_np

	function = FALSE

	edtype = astGetDataType( expr )

	select case astGetClass( expr )
	case AST_NODECLASS_CONST, AST_NODECLASS_ENUM
    	'' expr not a pointer?
    	if( edtype < FB_DATATYPE_POINTER ) then
    		'' not NULL?
    		if( astGetValInt( expr ) <> NULL ) then
    			exit function
    		else
    			return TRUE
    		end if
    	end if

	case else
    	'' expr not a pointer?
    	if( edtype < FB_DATATYPE_POINTER ) then
    		exit function
    	end if
	end select

	'' different types?
	if( pdtype <> edtype ) then

    	'' remove the pointers
    	pdtype_np = pdtype mod FB_DATATYPE_POINTER
    	edtype_np = edtype mod FB_DATATYPE_POINTER

    	'' 1st) is one of them an ANY PTR?
    	if( pdtype_np = FB_DATATYPE_VOID ) then
    		return TRUE
    	elseif( edtype_np = FB_DATATYPE_VOID ) then
    		return TRUE
    	end if

    	'' 2nd) same level of indirection?
    	if( (pdtype - pdtype_np) <> (edtype - edtype_np) ) then
    		exit function
    	end if

    	'' 3rd) same size and class?
    	if( (pdtype_np <= FB_DATATYPE_DOUBLE) and _
    		(edtype_np <= FB_DATATYPE_DOUBLE) ) then
    		if( symbGetDataSize( pdtype_np ) = symbGetDataSize( edtype_np ) ) then
    			if( symbGetDataClass( pdtype_np ) = symbGetDataClass( edtype_np ) ) then
    				return TRUE
    			end if
    		end if
    	end if

    	exit function
    end if

	'' check sub types
	function = symbIsEqual( psubtype, astGetSubType( expr ) )

end function

'':::::
function astGetInverseLogOp _
	( _
		byval op as integer _
	) as integer static

	select case as const op
	case AST_OP_EQ
		op = AST_OP_NE
	case AST_OP_NE
		op = AST_OP_EQ
	case AST_OP_GT
		op = AST_OP_LE
	case AST_OP_LT
		op = AST_OP_GE
	case AST_OP_GE
		op = AST_OP_LT
	case AST_OP_LE
		op = AST_OP_GT
	end select

	function = op

end function

'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
'' tree cloning and deletion
'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

'':::::
function astCloneTree _
	( _
		byval n as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr nn = any, p = any

	''
	if( n = NULL ) then
		return NULL
	end if

	''
	nn = astNewNode( INVALID, INVALID )
	astCopy( nn, n )

	'' walk
	p = n->l
	if( p <> NULL ) then
		nn->l = astCloneTree( p )
	end if

	p = n->r
	if( p <> NULL ) then
		nn->r = astCloneTree( p )
	end if

	'' profiled function have sub nodes
	if( n->class = AST_NODECLASS_CALL ) then
		p = n->call.profbegin
		if( p <> NULL ) then
			nn->call.profbegin = astCloneTree( p )
			nn->call.profend   = astCloneTree( n->call.profend )
		end if
	end if

	function = nn

end function

'':::::
sub astDelTree _
	( _
		byval n as ASTNODE ptr _
	)

	dim as ASTNODE ptr p = any

	''
	if( n = NULL ) then
		exit sub
	end if

	'' walk
	p = n->l
	if( p <> NULL ) then
		astDelTree( p )
	end if

	p = n->r
	if( p <> NULL ) then
		astDelTree( p )
	end if

	'' profiled function have sub nodes
	if( n->class = AST_NODECLASS_CALL ) then
		p = n->call.profbegin
		if( p <> NULL ) then
			astDelTree( p )
			astDelTree( n->call.profend )
		end if
	end if

	''
	astDelNode( n )

end sub

''::::
function astIsTreeEqual _
	( _
		byval l as ASTNODE ptr, _
		byval r as ASTNODE ptr _
	) as integer

    function = FALSE

    if( (l = NULL) or (r = NULL) ) then
    	if( l = r ) then
    		function = TRUE
    	end if
    	exit function
    end if

	if( l->class <> r->class ) then
		exit function
	end if

	if( l->dtype <> r->dtype ) then
		exit function
	end if

	if( l->subtype <> r->subtype ) then
		exit function
	end if

	select case as const l->class
	case AST_NODECLASS_VAR
		if( l->sym <> r->sym ) then
			exit function
		end if

		if( l->var.ofs <> r->var.ofs ) then
			exit function
		end if

	case AST_NODECLASS_FIELD
		if( l->sym <> r->sym ) then
			exit function
		end if

	case AST_NODECLASS_CONST
		const DBL_EPSILON = 2.2204460492503131e-016

		select case as const l->dtype
		case FB_DATATYPE_LONGINT, FB_DATATYPE_ULONGINT
			if( l->con.val.long <> r->con.val.long ) then
				exit function
			end if
		case FB_DATATYPE_SINGLE, FB_DATATYPE_DOUBLE
			if( abs( l->con.val.float - r->con.val.float ) > DBL_EPSILON ) then
				exit function
			end if
		case else
			if( l->con.val.int <> r->con.val.int ) then
				exit function
			end if
		end select

	case AST_NODECLASS_ENUM
		if( l->con.val.int <> r->con.val.int ) then
			exit function
		end if

	case AST_NODECLASS_PTR
		if( l->ptr.ofs <> r->ptr.ofs ) then
			exit function
		end if

	case AST_NODECLASS_IDX
		if( l->idx.ofs <> r->idx.ofs ) then
			exit function
		end if

		if( l->idx.mult <> r->idx.mult ) then
			exit function
		end if

	case AST_NODECLASS_BOP
		if( l->op.op <> r->op.op ) then
			exit function
		end if

		if( l->op.options <> r->op.options ) then
			exit function
		end if

		if( l->op.ex <> r->op.ex ) then
			exit function
		end if

	case AST_NODECLASS_UOP
		if( l->op.op <> r->op.op ) then
			exit function
		end if

		if( l->op.options <> r->op.options ) then
			exit function
		end if

	case AST_NODECLASS_ADDR
		if( l->sym <> r->sym ) then
			exit function
		end if

		if( l->op.op <> r->op.op ) then
			exit function
		end if

	case AST_NODECLASS_OFFSET
		if( l->sym <> r->sym ) then
			exit function
		end if

		if( l->ofs.ofs <> r->ofs.ofs ) then
			exit function
		end if

	case AST_NODECLASS_CONV
		'' do nothing, the l child will be checked below

	case AST_NODECLASS_CALL, AST_NODECLASS_BRANCH, _
		 AST_NODECLASS_LOAD, AST_NODECLASS_ASSIGN, _
		 AST_NODECLASS_LINK
		'' unpredictable nodes
		exit function

	end select

    '' check childs
	if( astIsTreeEqual( l->l, r->l ) = FALSE ) then
		exit function
	end if

	if( astIsTreeEqual( l->r, r->r ) = FALSE ) then
		exit function
	end if

    ''
	function = TRUE

end function

'':::::
function astIsClassOnTree _
	( _
		byval class_ as integer, _
		byval n as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr m = any

	''
	if( n = NULL ) then
		return NULL
	end if

	if( n->class = class_ ) then
		return n
	end if

	'' walk
	m = astIsClassOnTree( class_, n->l )
	if( m <> NULL ) then
		return m
	end if

	m = astIsClassOnTree( class_, n->r )
	if( m <> NULL ) then
		return m
	end if

	'' profiled function have sub nodes
	if( n->class = AST_NODECLASS_CALL ) then
		m = astIsClassOnTree( class_, n->call.profbegin )
		if( m <> NULL ) then
			return m
		end if
	end if

	function = NULL

end function

''::::
function astIsSymbolOnTree _
	( _
		byval sym as FBSYMBOL ptr, _
		byval n as ASTNODE ptr _
	) as integer

	dim as FBSYMBOL ptr s = any

	if( n = NULL ) then
		return FALSE
	end if

	select case as const n->class
	case AST_NODECLASS_VAR, AST_NODECLASS_IDX, AST_NODECLASS_FIELD, _
		 AST_NODECLASS_ADDR, AST_NODECLASS_OFFSET

		s = astGetSymbol( n )

		'' same symbol?
		if( s = sym ) then
			return TRUE
		end if

		'' passed by ref or by desc? can't do any assumption..
		if( s <> NULL ) then
			if( (s->attrib and _
				(FB_SYMBATTRIB_PARAMBYDESC or FB_SYMBATTRIB_PARAMBYREF)) > 0 ) then
				return TRUE
			end if
		end if

	'' pointer? could be pointing to source symbol too..
	case AST_NODECLASS_PTR
		return TRUE
	end select

	'' walk
	if( n->l <> NULL ) then
		if( astIsSymbolOnTree( sym, n->l ) ) then
			return TRUE
		end if
	end if

	if( n->r <> NULL ) then
		if( astIsSymbolOnTree( sym, n->r ) ) then
			return TRUE
		end if
	end if

	function = FALSE

end function

'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
'' tree routines
'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


'':::::
function astNewNode _
	( _
		byval class_ as integer, _
		byval dtype as integer, _
		byval subtype as FBSYMBOL ptr _
	) as ASTNODE ptr static

	dim as ASTNODE ptr n

	n = listNewNode( @ast.astTB )

	astInitNode( n, class_, dtype, subtype )

	function = n

end function

'':::::
sub astDelNode _
	( _
		byval n as ASTNODE ptr _
	) static

	if( n = NULL ) then
		exit sub
	end if

	listDelNode( @ast.astTB, n )

end sub

'':::::
function astIsADDR _
	( _
		byval n as ASTNODE ptr _
	) as integer static

	select case n->class
	case AST_NODECLASS_ADDR, AST_NODECLASS_OFFSET
		return TRUE
	case else
		return FALSE
	end select

end function

'':::::
function astGetValueAsInt _
	( _
		byval n as ASTNODE ptr _
	) as integer

  	select case as const astGetDataType( n )
  	case FB_DATATYPE_LONGINT, FB_DATATYPE_ULONGINT
  	    function = cint( astGetValLong( n ) )

  	case FB_DATATYPE_SINGLE, FB_DATATYPE_DOUBLE
  		function = cint( astGetValFloat( n ) )

  	case else
  		function = astGetValInt( n )
  	end select

end function

'':::::
function astGetValueAsStr _
	( _
		byval n as ASTNODE ptr _
	) as string

  	select case as const astGetDataType( n )
  	case FB_DATATYPE_LONGINT
  		function = str( astGetValLong( n ) )

  	case FB_DATATYPE_ULONGINT
  		function = str( cast( ulongint, astGetValLong( n ) ) )

  	case FB_DATATYPE_SINGLE, FB_DATATYPE_DOUBLE
  		function = str( astGetValFloat( n ) )

  	case FB_DATATYPE_BYTE, FB_DATATYPE_SHORT, FB_DATATYPE_INTEGER, FB_DATATYPE_ENUM
  		function = str( astGetValInt( n ) )

  	case else
  		function = str( cast( uinteger, astGetValInt( n ) ) )
  	end select

end function

'':::::
function astGetValueAsWstr _
	( _
		byval n as ASTNODE ptr _
	) as wstring ptr

    static as wstring * 64+1 res

  	select case as const astGetDataType( n )
  	case FB_DATATYPE_LONGINT
		res = wstr( astGetValLong( n ) )

	case FB_DATATYPE_ULONGINT
		res = wstr( cast( ulongint, astGetValLong( n ) ) )

  	case FB_DATATYPE_SINGLE, FB_DATATYPE_DOUBLE
		res = wstr( astGetValFloat( n ) )

  	case FB_DATATYPE_BYTE, FB_DATATYPE_SHORT, FB_DATATYPE_INTEGER, FB_DATATYPE_ENUM
  		res = wstr( astGetValInt( n ) )

  	case else
		res = wstr( cast( uinteger, astGetValInt( n ) ) )
  	end select

  	function = @res

end function

'':::::
function astGetValueAsLongInt _
	( _
		byval n as ASTNODE ptr _
	) as longint

  	select case as const astGetDataType( n )
  	case FB_DATATYPE_LONGINT, FB_DATATYPE_ULONGINT
  	    function = astGetValLong( n )

  	case FB_DATATYPE_SINGLE, FB_DATATYPE_DOUBLE
  		function = clngint( astGetValFloat( n ) )

  	case else
  		if( symbIsSigned( astGetDataType( n ) ) ) then
  			function = clngint( astGetValInt( n ) )
  		else
  			function = clngint( cuint( astGetValInt( n ) ) )
  		end if
  	end select

end function

'':::::
function astGetValueAsULongInt _
	( _
		byval n as ASTNODE ptr _
	) as ulongint

  	select case as const astGetDataType( n )
  	case FB_DATATYPE_LONGINT, FB_DATATYPE_ULONGINT
  	    function = astGetValLong( n )

  	case FB_DATATYPE_SINGLE, FB_DATATYPE_DOUBLE
  		function = culngint( astGetValFloat( n ) )

  	case else
  		function = culngint( cuint( astGetValInt( n ) ) )
  	end select

end function

'':::::
function astGetValueAsDouble _
	( _
		byval n as ASTNODE ptr _
	) as double

  	select case as const astGetDataType( n )
  	case FB_DATATYPE_LONGINT, FB_DATATYPE_ULONGINT
  	    function = cdbl( astGetValLong( n ) )

  	case FB_DATATYPE_SINGLE, FB_DATATYPE_DOUBLE
  		function = astGetValFloat( n )

  	case else
  		function = cdbl( astGetValInt( n ) )
  	end select

end function

'':::::
function astGetStrLitSymbol _
	( _
		byval n as ASTNODE ptr _
	) as FBSYMBOL ptr static

	dim as FBSYMBOL ptr s

    function = NULL

   	if( astIsVAR( n ) ) then
		s = astGetSymbol( n )
		if( s <> NULL ) then
			if( symbGetIsLiteral( s ) ) then
				function = s
			end if
		end if
	end if

end function

'':::::
sub astConvertValue _
	( _
		byval n as ASTNODE ptr, _
		byval v as FBVALUE ptr, _
		byval todtype as integer _
	) static

	hConvertValue( @n->con.val, n->dtype, v, todtype )

end sub

'':::::
function astCheckConst _
	( _
		byval dtype as integer, _
		byval n as ASTNODE ptr _
	) as ASTNODE ptr static

	dim as longint lval
	dim as ulongint ulval
	dim as double dval, dmin, dmax

	'' x86 assumptions

    select case as const dtype
    case FB_DATATYPE_SINGLE, FB_DATATYPE_DOUBLE

		if( dtype = FB_DATATYPE_SINGLE ) then
			dmin = 1.175494351e-38
			dmax = 3.402823466e+38
		else
			dmin = 2.2250738585072014e-308
			dmax = 1.7976931348623147e+308
		end if

		dval = abs( astGetValueAsDouble( n ) )
    	if( dval <> 0 ) then
    		if( (dval < dmin) or (dval > dmax) ) then
    			errReport( FB_ERRMSG_MATHOVERFLOW, TRUE )
			end if
		end if

	case FB_DATATYPE_LONGINT

		'' unsigned constant?
		if( symbIsSigned( astGetDataType( n ) ) = FALSE ) then
			'' too big?
			if( astGetValueAsULongInt( n ) > 9223372036854775807ULL ) then
				n = astNewCONV( dtype, NULL, n )
				errReportWarn( FB_WARNINGMSG_IMPLICITCONVERSION )
			end if
		end if

	case FB_DATATYPE_ULONGINT

		'' signed constant?
		if( symbIsSigned( astGetDataType( n ) ) ) then
			'' too big?
			if( astGetValueAsLongInt( n ) and &h8000000000000000 ) then
				n = astNewCONV( dtype, NULL, n )
				errReportWarn( FB_WARNINGMSG_IMPLICITCONVERSION )
			end if
		end if

    case FB_DATATYPE_BYTE, FB_DATATYPE_SHORT, _
    	 FB_DATATYPE_INTEGER, FB_DATATYPE_ENUM

		lval = astGetValueAsLongInt( n )
		if( (lval < ast_minlimitTB( dtype )) or _
			(lval > clngint( ast_maxlimitTB( dtype ) )) ) then
			n = astNewCONV( dtype, NULL, n )
			errReportWarn( FB_WARNINGMSG_IMPLICITCONVERSION )
		end if

    case FB_DATATYPE_UBYTE, FB_DATATYPE_CHAR, _
    	 FB_DATATYPE_USHORT, FB_DATATYPE_WCHAR, _
    	 FB_DATATYPE_UINT

		ulval = astGetValueAsULongInt( n )
		if( (ulval < culngint( ast_minlimitTB( dtype ) )) or _
			(ulval > ast_maxlimitTB( dtype )) ) then
			n = astNewCONV( dtype, NULL, n )
			errReportWarn( FB_WARNINGMSG_IMPLICITCONVERSION )
		end if

	case FB_DATATYPE_BITFIELD
		'' !!!WRITEME!!! use ->subtype's
	end select

	function = n

end function

''::::
function astLoad _
	( _
		byval n as ASTNODE ptr _
	) as IRVREG ptr

	if( n = NULL ) then
		return NULL
	end if

	function = astGetClassLoadCB( n->class )( n )

end function


