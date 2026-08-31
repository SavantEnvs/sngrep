INVITE sip:35104724@sip.cybercity.dk SIP/2.0
Via: SIP/2.0/UDP 192.168.1.2:5060;branch=z9hG4bKnp11888298-448e3777192.168.1.2;rport
From: "arik" <sip:35104723@sip.cybercity.dk>;tag=b56e6e
To: <sip:35104724@sip.cybercity.dk>
Call-ID: 11894297-4432a9f8@192.168.1.2
CSeq: 1 INVITE
User-Agent: Nero SIPPS IP Phone Version 2.0.51.16
Expires: 120
Accept: application/sdp
Content-Type: application/sdp
Content-Length: 270
Contact: <sip:35104723@192.168.1.2>
Max-Forwards: 70
Allow: INVITE, ACK, CANCEL, BYE, REFER, OPTIONS, NOTIFY, INFO

v=0
o=SIPPS 11888330 11888327 IN IP4 192.168.1.2
s=SIP call
c=IN IP4 192.168.1.2
t=0 0
m=audio 30000 RTP/AVP 0 8 97 2 3
a=rtpmap:0 pcmu/8000
a=rtpmap:8 pcma/8000
a=rtpmap:97 iLBC/8000
a=rtpmap:2 G726-32/8000
a=rtpmap:3 GSM/8000
a=fmtp:97 mode=20
a=sendrecv
