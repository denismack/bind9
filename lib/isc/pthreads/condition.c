/*
 * Copyright (C) 1998-2000  Internet Software Consortium.
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND INTERNET SOFTWARE CONSORTIUM
 * DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL
 * INTERNET SOFTWARE CONSORTIUM BE LIABLE FOR ANY SPECIAL, DIRECT,
 * INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING
 * FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
 * NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION
 * WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

/* $Id: condition.c,v 1.28 2001/01/05 02:17:02 bwelling Exp $ */

#include <config.h>

#include <errno.h>

#include <isc/condition.h>
#include <isc/msgs.h>
#include <isc/string.h>
#include <isc/time.h>
#include <isc/util.h>

isc_result_t
isc_condition_waituntil(isc_condition_t *c, isc_mutex_t *m, isc_time_t *t) {
	int presult;
	isc_result_t result;
	struct timespec ts;

	REQUIRE(c != NULL && m != NULL && t != NULL);

	/*
	 * POSIX defines a timespec's tv_sec as time_t.
	 */
	result = isc_time_secondsastimet(t, &ts.tv_sec);
	if (result != ISC_R_SUCCESS)
		return (result);

	/*
	 * POSIX defines a timespec's tv_nsec as long.  isc_time_nanoseconds
	 * ensures its return value is < 1 billion, which will fit in a long.
	 */
	ts.tv_nsec = (long)isc_time_nanoseconds(t);

	do {
#if ISC_MUTEX_PROFILE
		presult = pthread_cond_timedwait(c, &m->mutex, &ts);
#else
		presult = pthread_cond_timedwait(c, m, &ts);
#endif
		if (presult == 0)
			return (ISC_R_SUCCESS);
		if (presult == ETIMEDOUT)
			return (ISC_R_TIMEDOUT);
	} while (presult == EINTR);

	UNEXPECTED_ERROR(__FILE__, __LINE__,
			 "pthread_cond_timedwait() %s %s",
			 isc_msgcat_get(isc_msgcat, ISC_MSGSET_GENERAL,
					ISC_MSG_RETURNED, "returned %s"),
			 strerror(presult));
	return (ISC_R_UNEXPECTED);
}
