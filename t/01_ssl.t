use strict;
use Test::More;
use Plack::Handler::AnyEvent::HTTPD;
use AnyEvent;
use AnyEvent::HTTP;

BEGIN {
    my $can_run = eval {
        use Net::SSLeay;
        1;
    };
    if(! $can_run) {
        plan skip_all => "Couldn't load Net::SSLeay: $@";
    } else {
        plan tests => 4;
    };
};

my %config = (
    host => '127.0.0.1',
    #port => 8443,
    port => '00', # random port number
    ssl => {
	# A passwordless key+certificate for "localhost"
	# I don't recommend putting cert+key into your source code
	# Load them from a file unless it's just for testing. But it never is.
	
	# key_file => 'certs/testkey.pem',
	# cert_file => 'certs/testcert.pem',
	cert => <<'CERT',
-----BEGIN CERTIFICATE-----
MIIDkDCCAvmgAwIBAgIJAOQyGKZlWWy8MA0GCSqGSIb3DQEBBQUAMIGNMQswCQYD
VQQGEwJERTEPMA0GA1UECBMGSGVzc2VuMRIwEAYDVQQHEwlGcmFua2Z1cnQxDTAL
BgNVBAoTBFRlc3QxEjAQBgNVBAsTCWxvY2FsaG9zdDESMBAGA1UEAxMJbG9jYWxo
b3N0MSIwIAYJKoZIhvcNAQkBFhNub3doZXJlQGV4YW1wbGUuY29tMB4XDTEyMDcx
MzEwMDQ0MFoXDTIxMDkyOTEwMDQ0MFowgY0xCzAJBgNVBAYTAkRFMQ8wDQYDVQQI
EwZIZXNzZW4xEjAQBgNVBAcTCUZyYW5rZnVydDENMAsGA1UEChMEVGVzdDESMBAG
A1UECxMJbG9jYWxob3N0MRIwEAYDVQQDEwlsb2NhbGhvc3QxIjAgBgkqhkiG9w0B
CQEWE25vd2hlcmVAZXhhbXBsZS5jb20wgZ8wDQYJKoZIhvcNAQEBBQADgY0AMIGJ
AoGBAPaDBy1c5F8awRHz+/0g7mAob132CrVOB8mJtMH9wUccSGy5K1UK7pm506Ma
z6Mc+B/fiNf7alduQqidOo6fP1EfLTvap5ubDF0J86911hQU2jwvnxezTQsJCVmQ
Dh5Gn5+V3l20cBzMfw5kmvx++uM341MPxILiisKiEvOzmaNFAgMBAAGjgfUwgfIw
HQYDVR0OBBYEFMTJxKSp3goIm/cCm7fJncqCg5T+MIHCBgNVHSMEgbowgbeAFMTJ
xKSp3goIm/cCm7fJncqCg5T+oYGTpIGQMIGNMQswCQYDVQQGEwJERTEPMA0GA1UE
CBMGSGVzc2VuMRIwEAYDVQQHEwlGcmFua2Z1cnQxDTALBgNVBAoTBFRlc3QxEjAQ
BgNVBAsTCWxvY2FsaG9zdDESMBAGA1UEAxMJbG9jYWxob3N0MSIwIAYJKoZIhvcN
AQkBFhNub3doZXJlQGV4YW1wbGUuY29tggkA5DIYpmVZbLwwDAYDVR0TBAUwAwEB
/zANBgkqhkiG9w0BAQUFAAOBgQCDsSHofh5DQRxJ3JMrR2vFfulNxELLtlJX/5zN
A+Fjpux6wZxGl9jVgCVFH36nSgNNsf+0gd7fRW/Z0O04mRq16MroKIj4WvoPEOEk
OdFn+VrgE8g7uKT+EgL1YHqQnR9xEbmsmPc5rIZkodpZTSAhJ242oRbiwLsXZIZM
ljrcfg==
-----END CERTIFICATE-----
CERT
	key  => <<'KEY',
-----BEGIN RSA PRIVATE KEY-----
MIICXQIBAAKBgQD2gwctXORfGsER8/v9IO5gKG9d9gq1TgfJibTB/cFHHEhsuStV
Cu6ZudOjGs+jHPgf34jX+2pXbkKonTqOnz9RHy072qebmwxdCfOvddYUFNo8L58X
s00LCQlZkA4eRp+fld5dtHAczH8OZJr8fvrjN+NTD8SC4orCohLzs5mjRQIDAQAB
AoGAWzIMFK8Z2Uk3heHCJlnpde9fi947BenRHbDxCxdKSnlfHcG/Ex4ROROzBNMl
X42XCYuTv3tGUwP6axCHmj21mR5UszFuWINTLWrjqxR9YvR+NW+TRr65pLipnIrD
xYm5U2lVpFJE6FHbsyrKPfI0ycREQIQP5dASo0oIsgQuVp0CQQD8xf64Ooy/x013
rSLTpuhPgr7cb9ibU3C+Rtsi4HXUeLWLJ3ylD56IlALChW+nSI4VjBe695RWR/L/
If4+JVQjAkEA+aiSVSqRwidJmi7rPUoMl35OA0yTXTHl3ocZFsWQvGn+TCBFXBsa
yDMWoVyipFSaB74kERUCD56FjF3UtNtNdwJBANDRzM1raS1hu8i7WoMZZt+QtpYr
O/mNpB09MfmNDyqZEflEhL9juOdBx0nlrEi5Ms/wLQaDU6M3yzIkZgH3GpsCQQCl
WCtyFDtsprBsWN6bPMuSGah5LuH6Ou3OrxLCrh3paxlsOYM2OQ1Hwe4e+EcPJqjM
r/UbCxrOVWKFUC9riEKJAkAVcgY+aRR9ld0a4J1KHvOqjDiZ0hzY+bjDA0edSfTd
r2IZddTtyt0vTjdZIeMb4TO5qrcL5/G63QJnmqtWcvYt
-----END RSA PRIVATE KEY-----
KEY
    },
);

my $ready = AnyEvent->condvar;
my $server = Plack::Handler::AnyEvent::HTTPD->new(
    %config,
    server_ready => sub {
	my $url = "https://$_[0]->{host}:$_[0]->{port}";
        $ready->send($url);
    },
);

# Centralize the nasty object-bowel reaching
my $done = AnyEvent->condvar;
my $stop_server = sub {
    $done->send;
};

my $env = {};
my $app = sub {
    AnyEvent::postpone { $stop_server->() };
    #diag "Returning response from app";
    $env = $_[0];
    return [ 200, [], ['Serving https:// works OK'] ];
};

$server->register_service($app);
my $url = $ready->recv;
diag "Running on $url";

# Set up a timeout, just in case:
my $timeout = AnyEvent->timer(
    after => 10,
    cb => sub {
        diag "Timeout";
        $stop_server->();
    },
);

my $ok;
my ($headers, $content);
# Now launch a request against ourselves
#diag "Sending request to $url";
http_get $url => sub {
    #diag "Got response";
    ($content,$headers) = @_;
    $ok++;
    AnyEvent::postpone { $stop_server->() };
};

#diag "Entering server runloop";
$done->recv;

is $ok, 1, "We fetched the data from $url";
is $headers->{Status}, 200, "We got an OK response"
    or diag $headers->{Reason};

is $content, 'Serving https:// works OK', "Content is as expected";

is $env->{"psgi.url_scheme"}, 'https', "We got 'https' scheme in the application"
    or diag $env->{"psgi.url_scheme"};

done_testing();
