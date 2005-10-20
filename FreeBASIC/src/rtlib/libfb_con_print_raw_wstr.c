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
 * con_print_raw.c -- print raw data - no interpretation is done
 *
 * chng: sep/2005 written [mjs]
 *
 */

#include "fb_con.h"

void fb_ConPrintRawWstr( fb_ConHooks *handle,
                     	 const FB_WCHAR *pachText,
                     	 size_t TextLength )
{
    fb_Rect *pBorder = &handle->Border;
    fb_Coord *pCoord = &handle->Coord;
    while( TextLength!=0 ) {
        size_t RemainingWidth = pBorder->Right - pCoord->X + 1;
        size_t CopySize = (TextLength > RemainingWidth) ? RemainingWidth : TextLength;

        fb_hConCheckScroll( handle );

        if( handle->Write( handle,
                           (char *)pachText,
                           CopySize )!=TRUE )
            break;

        TextLength -= CopySize;
        pachText += CopySize;
        pCoord->X += CopySize;

        if( pCoord->X==(pBorder->Right + 1) ) {
            pCoord->X = pBorder->Left;
            pCoord->Y += 1;
        }
    }
}
