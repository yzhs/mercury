/*
** Copyright (C) 1995 University of Melbourne.
** This file may only be copied under the terms of the GNU Library General
** Public License - see the file COPYING.LIB in the Mercury distribution.
*/

#ifndef	LABEL_H
#define	LABEL_H

#include	"dlist.h"

typedef struct s_label
{
	const char	*e_name;   /* name of the procedure	     */
	Code		*e_addr;   /* address of the code	     */
#if defined(NATIVE_GC)
	int		e_det;	   /* determinism of the code        */
	int		e_offset;  /* offset into liveval table      */
#endif
} Label;

extern	void	do_init_entries(void);
extern	Label	*insert_entry(const char *name, Code *addr);
#if defined(NATIVE_GC)
extern  void    insert_gc_entry(const char *name, int det, int offset);
#endif
extern	Label	*lookup_label_name(const char *name);
extern	Label	*lookup_label_addr(const Code *addr);
extern	List	*get_all_labels(void);

extern  int 	entry_table_size;
	/* expected number of entries in the table   */
	/* we allocate 8 bytes per entry, or 16 with */
	/* native GC 				     */
#endif
