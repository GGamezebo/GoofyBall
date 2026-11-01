extends TestCase

## Server address input: typos in numeric addresses are rejected, hostnames pass.


func test_host_validation() -> void:
	for good in ["192.168.8.76", "127.0.0.1", "localhost", "nakama.example.com", "my-laptop"]:
		expect(OnlineConfig._is_valid_host(good), "accepts %s" % good)
	for bad in ["127.0.01", "192.168.8", "300.1.1.1", "1..2.3", "my laptop"]:
		expect(not OnlineConfig._is_valid_host(bad), "rejects %s" % bad)
