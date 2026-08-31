/*
 * mayhem/kat_sip_probe.c — mayhem/test.sh's REQUIRED behavioral oracle.
 *
 * A known-answer-test (KAT) probe: feeds sip_check_packet() (src/sip.c, the same
 * function driven by mayhem/fuzz_sip_check_packet.c and by capture.c in the real
 * program) the textbook RFC 3261 §24.1 INVITE example, then asserts the EXACT
 * values sngrep's own regex-based header/SDP parser is supposed to extract:
 * Call-ID, From, To, Contact, CSeq, method, and one parsed SDP media line with
 * its rtpmap format. It also feeds a "SIP/2.0 200 OK" response to check response
 * parsing.
 *
 * This is a plain, dynamically linked, run-once executable (no libFuzzer, no
 * fork()) — verify-repo's sabotage check LD_PRELOADs a shim whose constructor
 * `_exit(0)`s every non-whitelisted executable before main() runs, so a
 * neutered build produces EMPTY stdout here. mayhem/test.sh greps stdout for
 * the literal "KAT_TOTAL: <n>/<n> PASS" line this probe prints only after every
 * assertion below has actually run and passed — that string can never appear
 * from a sabotaged binary, only from a probe that genuinely executed and
 * verified every value. Any assertion mismatch prints "KAT_TOTAL: <p>/<n> PASS"
 * with p<n and this program exits 1.
 */
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "option.h"
#include "setting.h"
#include "sip.h"
#include "sip_msg.h"
#include "sip_call.h"
#include "media.h"
#include "packet.h"
#include "address.h"

static int checks_total = 0;
static int checks_passed = 0;

#define CHECK_STR(label, got, want) do { \
    checks_total++; \
    const char *_g = (got); \
    const char *_w = (want); \
    if (_g && strcmp(_g, _w) == 0) { \
        checks_passed++; \
        printf("KAT_OK  %-24s = %s\n", label, _g); \
    } else { \
        printf("KAT_FAIL %-24s got=[%s] want=[%s]\n", label, _g ? _g : "(null)", _w); \
    } \
} while (0)

#define CHECK_INT(label, got, want) do { \
    checks_total++; \
    long _g = (long)(got); \
    long _w = (long)(want); \
    if (_g == _w) { \
        checks_passed++; \
        printf("KAT_OK  %-24s = %ld\n", label, _g); \
    } else { \
        printf("KAT_FAIL %-24s got=%ld want=%ld\n", label, _g, _w); \
    } \
} while (0)

static packet_t *
make_packet(const char *text)
{
    address_t src, dst;
    memset(&src, 0, sizeof(src));
    memset(&dst, 0, sizeof(dst));
    strcpy(src.ip, "192.0.2.1");
    src.port = 5060;
    strcpy(dst.ip, "192.0.2.2");
    dst.port = 5060;

    packet_t *pkt = packet_create(4, 17, src, dst, 1);
    if (!pkt) {
        fprintf(stderr, "packet_create failed\n");
        exit(2);
    }
    packet_set_type(pkt, PACKET_SIP_UDP);
    packet_set_payload(pkt, (u_char *) text, (uint32_t) strlen(text));
    return pkt;
}

/* RFC 3261 section 24.1's canonical INVITE example (CRLF line endings). */
static const char *invite_msg =
    "INVITE sip:bob@example.com SIP/2.0\r\n"
    "Via: SIP/2.0/UDP host;branch=z9hG4bK776asdhds\r\n"
    "From: alice <sip:alice@example.com>;tag=1928301774\r\n"
    "To: bob <sip:bob@example.com>\r\n"
    "Call-ID: a84b4c76e66710@pc33.example.com\r\n"
    "CSeq: 314159 INVITE\r\n"
    "Contact: <sip:alice@pc33.example.com>\r\n"
    "Content-Type: application/sdp\r\n"
    "Content-Length: 151\r\n"
    "\r\n"
    "v=0\r\n"
    "o=alice 2890844526 2890844526 IN IP4 pc33.example.com\r\n"
    "s=Session SDP\r\n"
    "c=IN IP4 pc33.example.com\r\n"
    "t=0 0\r\n"
    "m=audio 49172 RTP/AVP 0\r\n"
    "a=rtpmap:0 PCMU/8000\r\n";

/* A matching 200 OK response, replaying the same Call-ID/CSeq (a retransmission
 * of an in-dialog response would normally have a different CSeq value; use a
 * fresh Call-ID here so this exercises response-line parsing independently). */
static const char *ok_msg =
    "SIP/2.0 200 OK\r\n"
    "Via: SIP/2.0/UDP host;branch=z9hG4bK776asdhds\r\n"
    "From: alice <sip:alice@example.com>;tag=1928301774\r\n"
    "To: bob <sip:bob@example.com>;tag=a6c85cf\r\n"
    "Call-ID: kat-response-check@pc33.example.com\r\n"
    "CSeq: 1 INVITE\r\n"
    "Content-Length: 0\r\n"
    "\r\n";

int
main(void)
{
    /* no_config=1: never touches /etc/sngreprc or $HOME/.sngreprc. */
    init_options(1);
    sip_init(200, 0, 0);

    /* ---- INVITE: header + SDP parsing ---- */
    packet_t *pkt = make_packet(invite_msg);
    sip_msg_t *msg = sip_check_packet(pkt);

    checks_total++;
    if (msg) {
        checks_passed++;
        printf("KAT_OK  %-24s = %s\n", "invite msg non-NULL", "yes");
    } else {
        printf("KAT_FAIL %-24s got=NULL\n", "invite msg non-NULL");
        printf("KAT_TOTAL: %d/%d PASS\n", checks_passed, checks_total);
        return 1;
    }

    {
        sip_call_t *call = sip_find_by_callid("a84b4c76e66710@pc33.example.com");
        CHECK_STR("callid", call ? call->callid : NULL, "a84b4c76e66710@pc33.example.com");
    }
    CHECK_INT("reqresp",        msg->reqresp,                SIP_METHOD_INVITE);
    CHECK_INT("cseq",           msg->cseq,                    314159);
    CHECK_STR("sip_from",       msg->sip_from,                "alice@example.com");
    CHECK_STR("sip_to",         msg->sip_to,                  "bob@example.com");
    CHECK_STR("sip_contact",    msg->sip_contact,              "alice@pc33.example.com");
    CHECK_STR("method_str",     sip_method_str(msg->reqresp),  "INVITE");

    checks_total++;
    int mediacnt = msg_media_count(msg);
    if (mediacnt == 1) {
        checks_passed++;
        printf("KAT_OK  %-24s = %d\n", "media_count", mediacnt);
    } else {
        printf("KAT_FAIL %-24s got=%d want=1\n", "media_count", mediacnt);
    }

    if (mediacnt >= 1) {
        sdp_media_t *media = vector_first(msg->medias);
        /* media_get_type() is declared in media.h but never defined in media.c
         * (dead upstream declaration — nothing links it in the real program
         * either) so read the public struct field directly instead. */
        CHECK_STR("media_type",       media->type,                     "audio");
        CHECK_STR("media_rtpmap(pt0)", media_get_format(media, 0),      "PCMU/8000");
    }

    /* ---- 200 OK: response-line parsing ---- */
    packet_t *pkt2 = make_packet(ok_msg);
    sip_msg_t *msg2 = sip_check_packet(pkt2);

    checks_total++;
    if (msg2) {
        checks_passed++;
        printf("KAT_OK  %-24s = %s\n", "200ok msg non-NULL", "yes");
        CHECK_INT("200ok reqresp", msg2->reqresp, 200);
        CHECK_STR("200ok method_str", sip_get_msg_reqresp_str(msg2), "200 OK");
    } else {
        printf("KAT_FAIL %-24s got=NULL\n", "200ok msg non-NULL");
    }

    printf("KAT_TOTAL: %d/%d PASS\n", checks_passed, checks_total);
    return (checks_passed == checks_total) ? 0 : 1;
}
