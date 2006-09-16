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


'' atomic and parentheses expression parsing
''
'' chng: sep/2004 written [v1ctor]


#include once "inc\fb.bi"
#include once "inc\fbint.bi"
#include once "inc\parser.bi"
#include once "inc\ast.bi"

'':::::
''ParentExpression=   '(' Expression ')' .
''
function cParentExpression _
	( _
		byref parexpr as ASTNODE ptr _
	) as integer

  	function = FALSE

  	'' '('
  	if( lexGetToken( ) <> CHAR_LPRNT ) then
  		exit function
  	end if

  	lexSkipToken( )

  	'' ++parent cnt
  	parser.prntcnt += 1

  	if( cExpression( parexpr ) = FALSE ) then
  		'' calling a SUB? it could be a BYVAL or nothing due the optional ()'s
  		if( fbGetPrntOptional( ) ) then
  			exit function
  		end if

  		if( errReport( FB_ERRMSG_EXPECTEDEXPRESSION ) = FALSE ) then
  			exit function
  		else
  			'' error recovery: skip until next ')', fake an expr
  			hSkipUntil( CHAR_RPRNT, TRUE )
  			parexpr = astNewCONSTi( 0, FB_DATATYPE_INTEGER )
  			return TRUE
  		end if
    end if

  	'' ')'
  	if( lexGetToken( ) = CHAR_RPRNT ) then
  		lexSkipToken( )
  		'' --parent cnt
  		parser.prntcnt -= 1

  	else
  		'' not calling a SUB or parent cnt = 0?
  		if( (fbGetPrntOptional( ) = FALSE) or (parser.prntcnt = 0) ) then
  			if( errReport( FB_ERRMSG_EXPECTEDRPRNT ) = FALSE ) then
  				exit function
  			else
  				'' error recovery: skip until next ')'
  				hSkipUntil( CHAR_RPRNT, TRUE )
  			end if
  		end if
  	end if

  	function = TRUE

end function

'':::::
private function hCtorCall _
	( _
		byval sym as FBSYMBOL ptr, _
		byref atom as ASTNODE ptr _
	) as integer

	dim as FBSYMBOL ptr tmp = any
	dim as integer isprnt = any
	dim as ASTNODE ptr procexpr = any

	'' skip symbol
	lexSkipToken( )

    '' alloc temp var
    tmp = symbAddTempVar( symbGetType( sym ), _
    					  sym, _
    					  FALSE, _
    					  FALSE )


	'' '('?
	if( lexGetToken( ) = CHAR_LPRNT ) then
		lexSkipToken( )
		isprnt = TRUE
	else
		isprnt = FALSE
	end if

	procexpr = cProcArgList( symbGetCompCtorHead( sym ), _
					  		 NULL, _
					  		 astBuildVarField( tmp ), _
					  		 TRUE, _
					  		 FALSE )
	if( procexpr = NULL ) then
		return FALSE
	end if

	if( isprnt ) then
		'' ')'?
		if( lexGetToken( ) <> CHAR_RPRNT ) then
			if( errReport( FB_ERRMSG_EXPECTEDRPRNT ) = FALSE ) then
				return FALSE
			else
				'' error recovery: skip until next ')'
				hSkipUntil( CHAR_RPRNT, TRUE )
			end if
		else
			lexSkipToken( )
		end if
	end if

	'' error recovery..
	if( astIsCALL( procexpr ) ) then
		atom = astNewCALLCTOR( procexpr, astBuildVarField( tmp ) )
	else
		atom = procexpr
	end if

	function = ( atom <> NULL )

end function

'':::::
private function hFindId _
	( _
		byval chain_ as FBSYMCHAIN ptr, _
		byref atom as ASTNODE ptr _
	) as integer static

    dim as FBSYMBOL ptr sym

    do
    	sym = chain_->sym
    	select case as const symbGetClass( sym )
		case FB_SYMBCLASS_CONST
			return cConstantEx( sym, atom )

		case FB_SYMBCLASS_PROC
			return cFunctionEx( sym, atom )

		case FB_SYMBCLASS_VAR
           	return cVariableEx( chain_, atom, fbGetCheckArray( ) )

        case FB_SYMBCLASS_FIELD
        	return cFieldVariable( NULL, chain_, atom, fbGetCheckArray( ) )

  		'' quirk-keyword?
  		case FB_SYMBCLASS_KEYWORD
  			return cQuirkFunction( sym->key.id, atom )

		case FB_SYMBCLASS_STRUCT, FB_SYMBCLASS_CLASS
			if( symbGetHasCtor( sym ) ) then
				return hCtorCall( sym, atom )
			end if
		end select

    	chain_ = symbChainGetNext( chain_ )
    loop while( chain_ <> NULL )

    function = FALSE

end function

'':::::
''Atom            =   Constant | Function | QuirkFunction | Variable | Literal .
''
function cAtom _
	( _
		byval chain_ as FBSYMCHAIN ptr, _
		byref atom as ASTNODE ptr _
	) as integer

  	atom = NULL

  	select case as const lexGetClass( )
  	case FB_TKCLASS_KEYWORD
  		return cQuirkFunction( cIdentifier( )->sym->key.id, atom )

  	case FB_TKCLASS_IDENTIFIER, FB_TKCLASS_QUIRKWD
  		if( chain_ = NULL ) then
  			chain_ = cIdentifier( )
  		end if

    	'' declared id?
    	if( chain_ <> NULL ) then
    		if( hFindId( chain_, atom ) ) then
    			return TRUE
    		end if
        end if

		'' error?
		if( errGetLast( ) <> FB_ERRMSG_OK ) then
			return FALSE
		end if

  		'' try to alloc an implicit variable..
    	if( lexGetClass( ) <> FB_TKCLASS_IDENTIFIER ) then
  			return FALSE
  		end if

  		if( fbLangOptIsSet( FB_LANG_OPT_IMPLICIT = FALSE ) ) then
  			errReportNotAllowed( FB_LANG_OPT_IMPLICIT, _
  								 FB_ERRMSG_IMPLICITVARSONLYVALIDINLANG )
  			return FALSE
  		end if

  		return cVariableEx( NULL, atom, fbGetCheckArray( ) )

	case FB_TKCLASS_NUMLITERAL
		return cNumLiteral( atom )

  	case FB_TKCLASS_STRLITERAL
        return cStrLiteral( atom )

  	case FB_TKCLASS_DELIMITER
		'' '.'?
		if( lexGetToken( ) <> CHAR_DOT ) then
			return FALSE
		end if

  		'' can be a global ns symbol access, or a WITH variable..
  		if( chain_ = NULL ) then
  			chain_ = cIdentifier( )
  		end if

  		if( chain_ <> NULL ) then
  			return hFindId( chain_, atom )

  		else
			if( errGetLast( ) <> FB_ERRMSG_OK ) then
				exit function
			end if

  			if( parser.stmt.with.sym <> NULL ) then
  				return cWithVariable( parser.stmt.with.sym, atom, fbGetCheckArray( ) )
  			end if
  		end if

  	end select

  	function = FALSE

end function

