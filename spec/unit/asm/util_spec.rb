require "asm/util"
require "spec_helper"
require "tempfile"
require "json"

describe ASM::Util do
  before do
    @tmpfile = Tempfile.new("AsmUtil_spec")
  end

  after do
    @tmpfile.unlink
  end

  describe "retries and timeouts" do
    it "should reraise unhandled exceptions" do
      expect do
        ASM::Util.block_and_retry_until_ready(1) do
          raise(ASM::Error)
        end
      end.to raise_error(ASM::Error)
    end

    it "should raise an exception on timeout" do
      expect do
        ASM::Util.block_and_retry_until_ready(1) do
          sleep 2
        end
      end.to raise_error(Timeout::Error)
    end

    it "should forgive a single exception" do
      mock_log = mock("foo")
      mock_log.expects(:info).with("Caught exception ASM::Error: ASM::Error")
      expects(:foo).twice.raises(ASM::Error).then.returns("bar")
      ASM::Util.block_and_retry_until_ready(5, ASM::Error, nil, mock_log) do
        foo
      end.should == "bar"
    end

    it "should defer to max sleep time" do
      expects(:foo).twice.raises(ASM::Error).then.returns("bar")
      ASM::Util.expects(:sleep).with(0.01)
      ASM::Util.block_and_retry_until_ready(5, ASM::Error, 0.01) do
        foo
      end.should == "bar"
    end
  end

  describe "when uuid is valid" do
    it "should create the corresponding serial number" do
      uuid = "423b69b2-8bd7-0dde-746b-75c98eb74d2b"
      ASM::Util.vm_uuid_to_serial_number(uuid).should == "VMware-42 3b 69 b2 8b d7 0d de-74 6b 75 c9 8e b7 4d 2b"
    end
  end

  describe "when uuid is not valid" do
    it "should raise an exception" do
      uuid = "lkasdjflkasdj"
      expect do
        ASM::Util.vm_uuid_to_serial_number(uuid)
      end.to raise_error
    end
  end

  it "should parse esxcli output" do
    stdout = <<-eos
Name                    Virtual Switch  Active Clients  VLAN ID
----------------------  --------------  --------------  -------
ISCSI0                  vSwitch3                     1       16
ISCSI1                  vSwitch3                     1       16
Management Network      vSwitch0                     1        0
Management Network (1)  vSwitch0                     1       28
VM Network              vSwitch0                     1        0
Workload Network        vSwitch2                     0       20
vMotion                 vSwitch1                     1       23

    eos
    result = {
      "exit_status" => 0,
      "stdout" => stdout
    }
    ASM::Util.stubs(:run_command_with_args).returns(result)
    endpoint = {}
    ret = ASM::Util.esxcli([], endpoint)
    expect(ret.size).to eq(7)
    expect(ret[3]["Name"]).to eq("Management Network (1)")
    expect(ret[3]["Virtual Switch"]).to eq("vSwitch0")
    expect(ret[3]["Active Clients"]).to eq("1")
    expect(ret[3]["VLAN ID"]).to eq("28")
  end

  describe "when hash is deep" do
    it "should sanitize password value" do
      raw = {"foo" => {"password" => "secret"}}
      ASM::Util.sanitize(raw).should == {"foo" => {"password" => "******"}}
    end

    it "should maintain password value" do
      raw = {"foo" => {"password" => "secret"}}
      ASM::Util.sanitize(raw)
      raw.should == {"foo" => {"password" => "secret"}}
    end
  end

  describe '#hostname_to_certname' do
    it "should generate a certname and not clobber the original hostname" do
      certname = "CrAzY_NaMe1234"
      expect(ASM::Util.hostname_to_certname(certname)).to eq("agent-crazyname1234")
      expect(certname).to eq("CrAzY_NaMe1234")
    end
  end

  describe "#deep_merge!" do
    it "should recursively merge one hash into another" do
      original = {"asm::fcdatastore" =>
                    {"drsmixh01:drs-cplmix03" =>
                       {"data_center" => "drsmix01dc", "datastore" => "drs-cplmix03",
                        "cluster" => "drsmix01dc", "ensure" => "present",
                        "esxhost" => "172.31.37.143", "lun" => nil, "iscsi_volume" => true}}}
      new = {"asm::fcdatastore" =>
               {"drsmixh01:drs-cplmix04" =>
                  {"data_center" => "drsmix01dc", "datastore" => "drs-cplmix04", "cluster" => "drsmix01dc",
                   "ensure" => "present", "esxhost" => "172.31.37.143", "lun" => nil, "iscsi_volume" => true}}}
      ASM::Util.deep_merge!(original, new)
      expect(original).to eq("asm::fcdatastore" =>
                                {"drsmixh01:drs-cplmix03" =>
                                   {"data_center" => "drsmix01dc", "datastore" => "drs-cplmix03", "cluster" => "drsmix01dc",
                                    "ensure" => "present", "esxhost" => "172.31.37.143", "lun" => nil, "iscsi_volume" => true},
                                 "drsmixh01:drs-cplmix04" =>
                                   {"data_center" => "drsmix01dc", "datastore" => "drs-cplmix04", "cluster" => "drsmix01dc",
                                    "ensure" => "present", "esxhost" => "172.31.37.143", "lun" => nil, "iscsi_volume" => true}})
    end
  end
end
