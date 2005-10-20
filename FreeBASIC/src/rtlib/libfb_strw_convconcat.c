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
 * strw_convconcat.c -- wstring concatenation + convertion functions
 *
 * chng: oct/2004 written [v1ctor]
 *
 */

#include "fb.h"

/*:::::*/
FBCALL FB_WCHAR *fb_WstrConcatWA ( const FB_WCHAR *str1, const void *str2, int str2_size )
{
	FB_WCHAR *dst, *d;
	int str1_len, str2_len;
	char *str2_ptr;

	if( str1 != NULL )
		str1_len = fb_wstr_Len( str1 );
	else
		str1_len = 0;

	FB_STRSETUP_FIX( str2, str2_size, str2_ptr, str2_len );

	/* NULL? */
	if( str1_len + str2_len == 0 )
	{
		dst = NULL;
	}
	else
	{
		/* alloc temp string */
    	dst = fb_wstr_AllocTemp( str1_len + str2_len );

		/* do the concatenation */
    	d = fb_wstr_Move( dst, str1, str1_len );
    	fb_wstr_ConvFromA( d, str2_len, str2_ptr );
    }

	/* delete temp? */
	if( str2_size == -1 )
		fb_hStrDelTemp( (FBSTRING *)str2 );

	return dst;
}

/*:::::*/
FBCALL FB_WCHAR *fb_WstrConcatAW ( const void *str1, int str1_size, const FB_WCHAR *str2 )
{
	FB_WCHAR *dst, *d;
	int str1_len, str2_len;
	char *str1_ptr;

	FB_STRSETUP_FIX( str1, str1_size, str1_ptr, str1_len );

	if( str2 != NULL )
		str2_len = fb_wstr_Len( str2 );
	else
		str2_len = 0;

	/* NULL? */
	if( str1_len + str2_len == 0 )
	{
		dst = NULL;
	}
	else
	{
		/* alloc temp string */
    	dst = fb_wstr_AllocTemp( str1_len + str2_len );

		/* do the concatenation */
    	d = fb_wstr_ConvFromA( dst, str1_len, str1_ptr );
    	if( str2_len > 0 )
    		fb_wstr_Move( d, str2, str2_len + 1 );
    	else
    		*d = L'\0';
    }

	/* delete temp? */
	if( str1_size == -1 )
		fb_hStrDelTemp( (FBSTRING *)str1 );

	return dst;
}

