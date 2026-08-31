INVITE sip:0097239287044@sip.cybercity.dk SIP/2.0
Via: SIP/2.0/UDP 192.168.1.2;branch=z9hG4bKnp83260863-46304c10192.168.1.2;rport
From: "arik" <sip:voi18062@sip.cybercity.dk>;tag=51449dc
To: <sip:0097239287044@sip.cybercity.dk>
Call-ID: 85216695-42dcdb1d@192.168.1.2
CSeq: 2 INVITE
Proxy-Authorization: Digest username="voi18062",realm="sip.cybercity.dk",uri="sip:192.168.1.2",nonce="1701b4767d49c41117c7b73a255a353",opaque="1701a1351f70795",nc="00000001",response="8258d3744c08b75f7af46cd0f1762510"
Content-Type: application/sdp
Content-Length: 270
Date: Mon, 04 Jul 2005 09:43:55 GMT
Contact: <sip:voi18062@192.168.1.2>
Expires: 120
Accept: application/sdp
Max-Forwards: 70
User-Agent: Nero SIPPS IP Phone Version 2.0.51.16
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
