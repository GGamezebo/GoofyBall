extends TestCase

## Two WebRTCTransports in one process, signaling wired directly: the direct link opens and
## carries both fast (unreliable) and sure (reliable) packets both ways.


func test_loopback_link_carries_packets() -> void:
	if not WebRTCTransport.is_supported():
		expect(false, "webrtc-native extension is not loaded")
		return
	var host := WebRTCTransport.new()
	var guest := WebRTCTransport.new()
	expect(host.open(2, PackedStringArray()), "host side opens")
	expect(guest.open(1, PackedStringArray()), "guest side opens")
	host.ev_signal_out.connect(guest.on_signal_in)
	guest.ev_signal_out.connect(host.on_signal_in)
	host.make_offer()

	var frames := 0
	while frames < 600 and not (host.is_ready(2) and guest.is_ready(1)):
		await tree.process_frame
		host.poll()
		guest.poll()
		frames += 1
	expect(host.is_ready(2) and guest.is_ready(1), "link opened (%d frames)" % frames)
	expect(not host.is_ready(3), "not ready for an unknown peer")

	expect(host.send(2, false, "fast".to_utf8_buffer()), "fast packet sent")
	expect(guest.send(1, true, "sure".to_utf8_buffer()), "sure packet sent")
	var got_guest: Array = []
	var got_host: Array = []
	for _i in 120:
		await tree.process_frame
		host.poll()
		guest.poll()
		got_guest.append_array(guest.receive())
		got_host.append_array(host.receive())
		if not got_guest.is_empty() and not got_host.is_empty():
			break
	expect(got_guest.size() == 1 and got_guest[0][0] == 1 and (got_guest[0][1] as PackedByteArray).get_string_from_utf8() == "fast",
		"guest got the fast packet from peer 1")
	expect(got_host.size() == 1 and got_host[0][0] == 2 and (got_host[0][1] as PackedByteArray).get_string_from_utf8() == "sure",
		"host got the sure packet from peer 2")
	host.close()
	guest.close()
	expect(not host.is_ready(2), "closed link is not ready")
