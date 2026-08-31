INVITE sip:97239287044@voip.brujula.net SIP/2.0
Via: SIP/2.0/UDP 192.168.1.2:5060;branch=z9hG4bKnp104984053-44ce4a41192.168.1.2;rport
From: "arik" <sip:816666@voip.brurjula.net>;tag=6433ef9
To: <sip:97239287044@voip.brujula.net>
Call-ID: 105090259-446faf7a@192.168.1.2
CSeq: 1 INVITE
User-Agent: Nero SIPPS IP Phone Version 2.0.51.16
Expires: 120
Accept: application/sdp
Content-Type: application/sdp
Content-Length: 272
Contact: <sip:816666@192.168.1.2>
Max-Forwards: 70
Allow: INVITE, ACK, CANCEL, BYE, REFER, OPTIONS, NOTIFY, INFO

v=0
o=SIPPS 105015165 105015162 IN IP4 192.168.1.2
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
