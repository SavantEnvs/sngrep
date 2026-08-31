INVITE sip:0097239287044@sip.cybercity.dk SIP/2.0
Via: SIP/2.0/UDP 192.168.1.2:5060;branch=z9hG4bKnp85213694-430aa1de192.168.1.2;rport
From: "arik" <sip:voi18062@sip.cybercity.dk>;tag=51449dc
To: <sip:0097239287044@sip.cybercity.dk>
Call-ID: 85216695-42dcdb1d@192.168.1.2
CSeq: 1 INVITE
User-Agent: Nero SIPPS IP Phone Version 2.0.51.16
Expires: 120
Accept: application/sdp
Content-Type: application/sdp
Content-Length: 270
Contact: <sip:voi18062@192.168.1.2>
Max-Forwards: 70
Allow: INVITE, ACK, CANCEL, BYE, REFER, OPTIONS, NOTIFY, INFO

v=0
o=SIPPS 85214742 85214739 IN IP4 192.168.1.2
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
