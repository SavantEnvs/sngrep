/*
 * mayhem/fuzz_sip_check_packet.c — libFuzzer harness for sngrep's SIP packet parser.
 *
 * Drives sip_check_packet(), the exact function capture.c calls for every captured
 * packet (src/capture.c:1034 `if (sip_check_packet(packet))`). The fuzz input is
 * treated as the reassembled transport payload of one packet (UDP/TCP/TLS SIP
 * datagram), matching what capture.c hands to packet_set_payload() before calling
 * sip_check_packet(). This exercises:
 *   - Call-ID / X-Call-ID header extraction (sip_get_callid / sip_get_xcallid)
 *   - request/response line + CSeq parsing (sip_get_msg_reqresp)
 *   - From/To/Contact header parsing (sip_parse_msg_payload)
 *   - for INVITE dialogs: SDP media line parsing (sip_parse_msg_media) and extra
 *     header parsing (sip_parse_extra_headers)
 * all via the real regex-based parsers in src/sip.c, without any file I/O.
 *
 * No filesystem access: sip_init()/init_options() are called once with no_config=1
 * (skip /etc/sngreprc and $HOME/.sngreprc reads) so the harness takes bytes only
 * from the fuzzer.
 */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "option.h"
#include "setting.h"
#include "sip.h"
#include "packet.h"
#include "address.h"

/* Bound total in-memory call state so a long fuzzing session doesn't grow without
 * limit; sip_calls_rotate() evicts the oldest unlocked call once this is hit
 * (mirrors capture.limit in real usage, just much smaller — kept low because each
 * fuzzer-generated Call-ID is normally unique, so almost every accepted input
 * opens a brand new call). */
#define FUZZ_CALL_LIMIT 200

static void
fuzz_one_time_init(void)
{
    /* no_config=1: never touches /etc/sngreprc, $HOME/.sngreprc, or $SNGREPRC —
     * the harness takes bytes only from the fuzzer, never the filesystem. */
    init_options(1);
    /* only_calls=0, no_incomplete=0: widest coverage of call-creation paths
     * (requests AND responses may start a tracked call). */
    sip_init(FUZZ_CALL_LIMIT, 0, 0);
}

int
LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    static int inited = 0;
    if (!inited) {
        fuzz_one_time_init();
        inited = 1;
    }

    /* sip_check_packet() itself rejects anything over MAX_SIP_PAYLOAD (10240) by
     * returning NULL without touching the payload bytes further — cap here too so
     * we don't waste cycles copying huge inputs libFuzzer will never get coverage
     * from beyond that check. */
    if (size == 0 || size > 10240)
        return 0;

    address_t src, dst;
    memset(&src, 0, sizeof(src));
    memset(&dst, 0, sizeof(dst));
    strcpy(src.ip, "127.0.0.1");
    src.port = 5060;
    strcpy(dst.ip, "127.0.0.2");
    dst.port = 5060;

    packet_t *pkt = packet_create(4 /* ip_version */, 17 /* IPPROTO_UDP */, src, dst, 1 /* id */);
    if (!pkt)
        return 0;
    packet_set_type(pkt, PACKET_SIP_UDP);
    packet_set_payload(pkt, (u_char *) data, (uint32_t) size);

    sip_msg_t *msg = sip_check_packet(pkt);
    if (!msg) {
        /* sip_check_packet() only stores `pkt` into a message (and thus a call)
         * on the success path; every rejection path leaves us owning it. */
        packet_destroy(pkt);
    }
    /* On success `pkt` is now owned by msg->packet, and msg is owned by its call
     * (calls.list) — both released later by sip_calls_rotate()/sip_deinit(),
     * exactly like a real long-running capture session. */

    return 0;
}
