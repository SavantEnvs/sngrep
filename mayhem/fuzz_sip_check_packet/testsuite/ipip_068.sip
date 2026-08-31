INVITE sip:1bdaa608131517540001@172.28.1.3;transport=tcp SIP/2.0
Via: SIP/2.0/TCP 10.15.197.103:5090;branch=z9hG4bK8JQkQhxdSmM
To: <sip:1bdaa608131517540000@10.15.193.31>
From: <sip:1bdaa608131517540000@10.15.197.103>;tag=jr57na6shh
Call-Id: 1RLuVzzBClYCf2
CSeq: 6 INVITE
Max-Forwards: 68
Contact: <sip:1bdaa608131517540000-1bdaa608131517540000-ashteadiev-4@10.15.197.103:5090;transport=tcp>
Content-Type: application/sdp
Content-Length: 649

v=0
o=- 8566248303013635582 8175253998610074627 IN IP4 10.15.194.45
s=-
c=IN IP4 10.15.194.45
t=0 0
m=audio 50232 RTP/AVP 0 111 109 18 8 96 101 103 9
a=rtpmap:0 PCMU/8000
a=rtpmap:111 OPUS/48000/2
a=fmtp:111 useinbandfec=1;usedtx=1
a=rtpmap:109 OPUS/16000
a=fmtp:109 useinbandfec=1;usedtx=1
a=rtpmap:18 G729/8000
a=fmtp:18 annexb=no
a=rtpmap:8 PCMA/8000
a=rtpmap:96 iLBC/8000
a=fmtp:96 mode=20
a=rtpmap:101 telephone-event/8000
a=fmtp:101 0-15
a=rtpmap:103 telephone-event/16000
a=fmtp:103 0-15
a=rtpmap:9 G722/8000
a=sendrecv
a=rtcp-fb:111 ccm tmmbr
a=rtcp-fb:109 ccm tmmbr
a=ssrc:2348060575 cname:G1C/FVTf7W2cspeyYobiWw==
