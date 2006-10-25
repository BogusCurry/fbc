''	FreeBASIC - 32-bit BASIC Compiler.
''	Copyright (C) 2004-2007 The FreeBASIC development team.
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


'' function call's arguments list (called "param" by mistake)
''
'' chng: sep/2004 written [v1ctor]


#include once "inc\fb.bi"
#include once "inc\fbint.bi"
#include once "inc\list.bi"
#include once "inc\parser.bi"
#include once "inc\ast.bi"

type FBCTX
	arglist		as TLIST
end type

#define hInstPtrMode(ip) iif( astIsCONST( ip ), FB_PARAMMODE_BYVAL, INVALID )

'' globals
	dim shared ctx as FBCTX


'':::::
sub parserProcCallInit( )

	listNew( @ctx.arglist, 32*4, len( FB_CALL_ARG ), LIST_FLAGS_NOCLEAR )

end sub

sub parserProcCallEnd( )

	listFree( @ctx.arglist )

end sub

'':::::
''ProcArg        =   BYVAL? (ID(('(' ')')? | Expression) .
''
private function hProcArg _
	( _
		byval proc as FBSYMBOL ptr, _
		byval param as FBSYMBOL ptr, _
		byval argnum as integer, _
		byref expr as ASTNODE ptr, _
		byref amode as integer, _
		byval isfunc as integer _
	) as integer

	dim as integer pmode = any
	dim as FBSYMBOL ptr oldsym = any

	function = FALSE

	pmode = symbGetParamMode( param )
	amode = INVALID
	expr = NULL

	'' BYVAL?
	if( lexGetToken( ) = FB_TK_BYVAL ) then
		lexSkipToken( )
		amode = FB_PARAMMODE_BYVAL
	end if

	oldsym = parser.ctxsym
	parser.ctxsym = symbGetSubType( param )

	'' Expression
	if( cExpression( expr ) = FALSE ) then

		'' error?
		if( errGetLast( ) <> FB_ERRMSG_OK ) then
			parser.ctxsym = oldsym
			exit function
		end if

		if( isfunc ) then
			expr = NULL

		else
			'' failed and expr not null?
			if( expr <> NULL ) then
				parser.ctxsym = oldsym
				exit function
			end if

			'' check for BYVAL if it's the first param, due the optional ()'s
			if( (argnum = 0) and (amode = INVALID) ) then
				'' BYVAL?
				if( hMatch( FB_TK_BYVAL ) ) then
					amode = FB_PARAMMODE_BYVAL
					if( cExpression( expr ) = FALSE ) then
						expr = NULL
					end if
				end if
			end if
		end if

	end if

	parser.ctxsym = oldsym

	if( expr = NULL ) then

		'' check if argument is optional
		if( symbGetIsOptional( param ) = FALSE ) then
			if( pmode <> FB_PARAMMODE_VARARG ) then
				if( errReport( FB_ERRMSG_ARGCNTMISMATCH ) = FALSE ) then
					exit function
				else
					'' error recovery: fake an expr
					expr = astNewCONSTz( symbGetType( param ), symbGetSubType( param ) )
				end if

			else
				exit function
			end if
		end if

	else

		'' '('')'?
		if( pmode = FB_PARAMMODE_BYDESC ) then
			if( lexGetToken( ) = CHAR_LPRNT ) then
				if( lexGetLookAhead(1) = CHAR_RPRNT ) then
					if( amode <> INVALID ) then
						if( errReport( FB_ERRMSG_PARAMTYPEMISMATCH ) = FALSE ) then
							exit function
						end if
					end if
					lexSkipToken( )
					lexSkipToken( )
					amode = FB_PARAMMODE_BYDESC
				end if
			end if
    	end if

    end if

	''
	if( amode <> INVALID ) then
		if( amode <> pmode ) then
            if( pmode <> FB_PARAMMODE_VARARG ) then
            	'' allow BYVAL params passed to BYREF/BYDESC args
            	'' (to pass NULL to pointers and so on)
            	if( amode <> FB_PARAMMODE_BYVAL ) then
					if( amode <> pmode ) then
						if( errReport( FB_ERRMSG_PARAMTYPEMISMATCH ) = FALSE ) then
							exit function
						else
							'' error recovery: discard arg mode
							amode = pmode
						end if
					end if
				end if
			end if
		end if
	end if

	function = TRUE

end function

'':::::
''ProcParam         =   BYVAL? (ID(('(' ')')? | Expression) .
''
private function hOvlProcArg _
	( _
		byval argnum as integer, _
		byval arg as FB_CALL_ARG ptr, _
		byval isfunc as integer _
	) as integer

	dim as FBSYMBOL ptr oldsym = any

	function = FALSE

	arg->expr = NULL
	arg->mode = INVALID

	'' BYVAL?
	if( hMatch( FB_TK_BYVAL ) ) then
		arg->mode = FB_PARAMMODE_BYVAL
	end if

	oldsym = parser.ctxsym
	parser.ctxsym = NULL

	'' Expression
	if( cExpression( arg->expr ) = FALSE ) then

		'' error?
		if( errGetLast( ) <> FB_ERRMSG_OK ) then
			parser.ctxsym = oldsym
			exit function
		end if

		'' function? assume as optional..
		if( isfunc ) then
			arg->expr = NULL

		else
			'' failed and expr not null?
			if( arg->expr <> NULL ) then
				parser.ctxsym = oldsym
				exit function
			end if

			'' check for BYVAL if it's the first param, due the optional ()'s
			if( (argnum = 0) and (arg->mode = INVALID) ) then
				'' BYVAL?
				if( hMatch( FB_TK_BYVAL ) ) then
					arg->mode = FB_PARAMMODE_BYVAL
					if( cExpression( arg->expr ) = FALSE ) then
						arg->expr = NULL
					end if
				end if
			end if
		end if

	end if

	parser.ctxsym = oldsym

	'' not optional?
	if( arg->expr <> NULL ) then
		'' '('')'?
		if( lexGetToken( ) = CHAR_LPRNT ) then
			if( lexGetLookAhead(1) = CHAR_RPRNT ) then
				if( arg->mode <> INVALID ) then
					if( errReport( FB_ERRMSG_PARAMTYPEMISMATCH ) = FALSE )then
						exit function
					end if
				end if
				lexSkipToken( )
				lexSkipToken( )
				arg->mode = FB_PARAMMODE_BYDESC
			end if
		end if

    end if

	function = TRUE

end function

'':::::
private sub hDelArgNodes _
	( _
		byval arg as FB_CALL_ARG ptr _
	) static

	dim as FB_CALL_ARG ptr nxt

	do while( arg <> NULL )
		nxt = arg->next
		listDelNode( @ctx.arglist, arg )
		arg = nxt
	loop

end sub

'':::::
#macro hAllocOvlProcArg( arg, arg_head, arg_tail )
	arg = listNewNode( @ctx.arglist )
	if( arg_head = NULL ) then
		arg_head = arg
	else
		arg_tail->next = arg
	end if
	arg_tail = arg
	arg->next = NULL
#endmacro

'':::::
''ProcArgList     =    ProcArg (DECL_SEPARATOR ProcArg)* .
''
private function hOvlProcArgList _
	( _
		byval proc as FBSYMBOL ptr, _
		byval thisexpr as ASTNODE ptr, _
		byval isfunc as integer, _
		byval optonly as integer _
	) as ASTNODE ptr

    dim as integer args = any, i = any, params = any
    dim as ASTNODE ptr procexpr = any
    dim as FBSYMBOL ptr param = any, ovlproc = any
    dim as FB_CALL_ARG ptr arg_head = any, arg_tail = any, arg = any, nxt = any
    dim as FB_ERRMSG err_num = any

	function = NULL

	args = 0
	params = symGetProcOvlMaxParams( proc )

	'' no parms? (could happen by mistake..)
	if( params = iif( thisexpr = NULL, 0, 1 ) ) then
		'' sub? check the optional parentheses
		if( isfunc = FALSE ) then
			'' '('
			if( hMatch( CHAR_LPRNT ) ) then
				'' ')'
				if( hMatch( CHAR_RPRNT ) = FALSE ) then
					if( errReport( FB_ERRMSG_EXPECTEDRPRNT ) = FALSE ) then
						exit function
					else
						'' error recovery: skip until next ')'
						hSkipUntil( CHAR_RPRNT, TRUE )
					end if
				end if
			end if
		end if

		procexpr = astNewCALL( proc, NULL )

		'' method call?
		if( thisexpr <> NULL ) then
			if( astNewARG( procexpr, _
						   thisexpr, _
						   INVALID, _
					   	   hInstPtrMode( thisexpr ) ) = NULL ) then
				exit function
			end if
		end if

		return procexpr
	end if

	arg_head = NULL
	arg_tail = NULL

	'' method call?
	if( thisexpr <> NULL ) then
        '' alloc a new arg
		hAllocOvlProcArg( arg, arg_head, arg_tail )

		arg->expr = thisexpr
		arg->mode = hInstPtrMode( thisexpr )
		args += 1
	end if

	if( optonly = FALSE ) then
		do
			'' count mismatch?
			if( args >= params ) then
				if( errReport( FB_ERRMSG_ARGCNTMISMATCH ) = FALSE ) then
					exit function
				else
					'' error recovery: skip until next stmt or ')'
					if( isfunc ) then
						hSkipUntil( CHAR_RPRNT )
					else
						hSkipStmt( )
					end if

					args -= 1
					exit do
				end if
			end if

			'' alloc a new arg
			hAllocOvlProcArg( arg, arg_head, arg_tail )

			if( hOvlProcArg( args, arg, isfunc ) = FALSE ) then
				'' not an error? (could be an optional)
				if( errGetLast( ) <> FB_ERRMSG_OK ) then
					hDelArgNodes( arg_head )
					exit function
				end if
			end if

			'' ','?
			if( lexGetToken( ) <> CHAR_COMMA ) then
				'' only count this arg if it isn't optional
				if( arg->expr <> NULL ) then
					args += 1
				end if

				exit do
			end if

			lexSkipToken( )

			'' next
			args += 1
		loop
	end if

	'' try finding the closest overloaded proc
	ovlproc = symbFindClosestOvlProc( proc, args, arg_head, @err_num )
	if( ovlproc = NULL ) then
		if( err_num = FB_ERRMSG_OK ) then
			err_num = FB_ERRMSG_NOMATCHINGPROC
		end if

		errReportParam( proc, 0, NULL, err_num )

		hDelArgNodes( arg_head )
		if( errGetLast( ) <> FB_ERRMSG_OK ) then
			exit function
		else
			'' error recovery: fake an expr
			procexpr = astNewCONSTz( symbGetType( proc ), symbGetSubType( proc ) )
			return procexpr
		end if
	end if

	proc = ovlproc

	procexpr = astNewCALL( proc, NULL )

    '' add to tree
	param = symbGetProcLastParam( proc )
	arg = arg_head
	for i = 0 to args-1
        nxt = arg->next

		if( astNewARG( procexpr, arg->expr, INVALID, arg->mode ) = NULL ) then
			hDelArgNodes( arg )
			if( errReport( FB_ERRMSG_PARAMTYPEMISMATCH ) = FALSE ) then
				exit function
			else
				'' error recovery: fake an expr (don't try to fake an arg,
				'' different modes and param types like "as any" would break AST)
				procexpr = astNewCONSTz( symbGetType( proc ), symbGetSubType( proc ) )
				return procexpr
			end if
		end if

		listDelNode( @ctx.arglist, arg )

		'' next
		param = symbGetProcPrevParam( proc, param )
		arg = nxt
	next

	'' add the end-of-list optional args, if any
	params = symbGetProcParams( proc )
    do while( args < params )
		astNewARG( procexpr, NULL, INVALID, INVALID )

		'' next
		args += 1
		param = symbGetProcPrevParam( proc, param )
	loop

	function = procexpr

end function

'':::::
''ProcArgList     =    ProcArg (DECL_SEPARATOR ProcArg)* .
''
function cProcArgList _
	( _
		byval proc as FBSYMBOL ptr, _
		byval ptrexpr as ASTNODE ptr, _
		byval thisexpr as ASTNODE ptr, _
		byval isfunc as integer, _
		byval optonly as integer _
	) as ASTNODE ptr

    dim as integer args = any, params = any, mode = any
    dim as FBSYMBOL ptr param = any
    dim as ASTNODE ptr procexpr = any, expr = any

	'' overloaded?
	if( symbGetProcIsOverloaded( proc ) ) then
		'' only if there's more than one overloaded function
		if( symbGetProcOvlNext( proc ) <> NULL ) then
			return hOvlProcArgList( proc, thisexpr, isfunc, optonly )
		end if
	end if

	function = NULL

    procexpr = astNewCALL( proc, ptrexpr )

	args = 0
	params = symbGetProcParams( proc )
	param = symbGetProcLastParam( proc )

	'' method call?
	if( thisexpr <> NULL ) then
		if( astNewARG( procexpr, _
					   thisexpr, _
					   INVALID, _
					   hInstPtrMode( thisexpr ) ) = NULL ) then
			exit function
		end if

		args += 1
		param = symbGetProcPrevParam( proc, param )
	end if

	'' proc has no args?
	if( params = iif( thisexpr <> NULL, 1, 0 ) ) then
		'' sub? check the optional parentheses
		if( isfunc = FALSE ) then
			'' '('
			if( lexGetToken( ) = CHAR_LPRNT ) then
				lexSkipToken( )
				'' ')'
				if( lexGetToken( ) <> CHAR_RPRNT ) then
					if( errReport( FB_ERRMSG_EXPECTEDRPRNT ) = FALSE ) then
						exit function
					else
						'' error recovery: skip until next ')'
						hSkipUntil( CHAR_RPRNT, TRUE )
					end if
				else
					lexSkipToken( )
				end if
			end if
		end if

		return procexpr
	end if

	if( optonly = FALSE ) then
		do
			'' count mismatch?
			if( args >= params ) then
				if( param->param.mode <> FB_PARAMMODE_VARARG ) then
					if( errReport( FB_ERRMSG_ARGCNTMISMATCH ) = FALSE ) then
						exit function
					else
						'' error recovery: skip until next stmt or ')'
						if( isfunc ) then
							hSkipUntil( CHAR_RPRNT )
						else
							hSkipStmt( )
						end if

						args -= 1
						exit do
					end if
				end if
			end if

			if( hProcArg( proc, param, args, expr, mode, isfunc ) = FALSE ) then
				'' not an error? (could be an optional)
				if( errGetLast( ) <> FB_ERRMSG_OK ) then
					exit function
				else
					exit do
				end if
			end if

			'' add to tree
			if( astNewARG( procexpr, expr, INVALID, mode ) = NULL ) then
				if( errGetLast( ) <> FB_ERRMSG_OK ) then
					exit function
				else
					'' error recovery: skip until next stmt or ')'
					if( isfunc ) then
						hSkipUntil( CHAR_RPRNT )
					else
						hSkipStmt( )
					end if

					'' don't try to fake an arg, different modes and param
					'' types like "as any" would break AST
					astDelTree( procexpr )
					procexpr = astNewCONSTz( symbGetType( proc ), _
											 symbGetSubType( proc ) )
					return procexpr
				end if
			end if

			'' next
			args += 1
			if( args < params ) then
				param = symbGetProcPrevParam( proc, param )
			end if

		'' ','?
		loop while( hMatch( CHAR_COMMA ) )
	end if

	'' if not all args were given, check for the optional ones
	do while( args < params )
		'' var-arg? can't be optional..
		if( param->param.mode = FB_PARAMMODE_VARARG ) then
			exit do
		end if

		'' not optional?
		if( symbGetIsOptional( param ) = FALSE ) then
			if( errReport( FB_ERRMSG_ARGCNTMISMATCH ) = FALSE ) then
				exit function
			else
				'' error recovery: fake an expr
				astDelTree( procexpr )
				procexpr = astNewCONSTz( symbGetType( proc ), _
										 symbGetSubType( proc ) )
				return procexpr
			end if
		end if

		'' add to tree
		if( astNewARG( procexpr, NULL, INVALID, INVALID ) = NULL ) then
			exit function
		end if

		'' next
		args += 1
		param = symbGetProcPrevParam( proc, param )
	loop

	function = procexpr

end function

