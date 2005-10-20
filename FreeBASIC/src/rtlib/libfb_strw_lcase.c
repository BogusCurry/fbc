/*
 *  libfb - FreeBASIC's runtime library
 *	Copyright (C) 2004-2005 Andre V. T. Vicentini (av1ctor@yahoo.com.br) and others.
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/*
 * strw_lcase.c -- lcasew$ function
 *
 * chng: ago/2005 written [v1ctor]
 *
 */

#include "fb.h"


/*:::::*/
FBCALL FB_WCHAR *fb_WstrLcase ( const FB_WCHAR *src )
{
	FB_WCHAR *dst, *d;
	const FB_WCHAR *s;
	FB_WCHAR c;
	int chars, i;

	if( src == NULL )
		return NULL;

	chars = fb_wstr_Len( src );

	/* alloc temp string */
	dst = fb_wstr_AllocTemp( chars );
	if( dst == NULL )
		return NULL;

	/* to upper */
	s = src;
	d = dst;
	for( i = 0; i < chars; i++ )
    {
		c = *s++;

		if( fb_wstr_IsUpper( c ) )
			c = fb_wstr_ToLower( c );

		*d++ = c;
	}

	/* null char */
	*d = _LC('\0');

	return dst;
}
