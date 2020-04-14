require "aws-sdk"
require "dotenv"
require "byebug"

Dotenv.load

class Spotter
  INSTANCE_TYPE = "t3.xlarge"
  AMI = "ami-071487fbfaf740f89"
  ROOT_VOLUME_ID = "vol-03e1d84f2f3ee1d09"
  HOME_VOLUME_ID = "vol-010407762ab353cef"

  def initialize
    @client = Aws::EC2::Client.new(region: "us-east-2")
  end

  def get_spot_info
    resp = @client.describe_spot_price_history({
      start_time: Time.now,
      instance_types: [INSTANCE_TYPE],
      product_descriptions: [
        "Linux/UNIX (Amazon VPC)",
      ],
    })
    resp[:spot_price_history].sort do |sp1, sp2|
      sp1[:spot_price].to_f <=> sp2[:spot_price].to_f
    end[0]
  end

  def get_spot_instance
    spot = get_spot_info

    resp = @client.request_spot_instances({
      instance_count: 1,
      launch_specification: {
        # iam_instance_profile: {
        #   arn: "arn:aws:iam::123456789012:instance-profile/my-iam-role",
        # },
        image_id: AMI,
        instance_type: INSTANCE_TYPE,
        key_name: "id_rsa",
        placement: {
          availability_zone: spot[:availability_zone]
        },
        security_group_ids: [
          "launch-wizard-9",
        ],
      },
      spot_price: (spot[:spot_price].to_f + 0.0001).to_s, # ensure it's filled immediately
      type: "persistent",
    })

    puts "Requesting instance with spot price #{spot[:spot_price]}"
    request_id = resp.spot_instance_requests[0].spot_instance_request_id

    sleep 5


    puts "Getting instance id..."
    resp = @client.describe_spot_instance_requests({
      spot_instance_request_ids: [request_id]
    })
    instance_id = resp.spot_instance_requests[0].instance_id
    resp = @client.describe_instances({instance_ids: [instance_id]})
    public_dns_name = resp.reservations[0].instances[0].public_dns_name
    root_volume_id = resp.reservations[0].instances[0].block_device_mappings[0].ebs.volume_id

    sleep 10

    puts "Stopping instance..."

    @client.stop_instances({instance_ids: [instance_id]})
    sleep 10

    ######################################3

    puts "Attaching root/home volumes..."
    attach_volumes(root_volume_id, instance_id)

    puts "Starting instance..."
    @client.start_instances({instance_ids: [instance_id]})

    # TODO: need to cancel spot request, but keep instances alive.

    puts public_dns_name
  end

  def attach_volumes(existing_root_volume_id, instance_id)
    attached = false

    while !attached do
      putc "."
      begin
        @client.detach_volume({volume_id: existing_root_volume_id})

        sleep 10
        # attach the root volume
        @client.attach_volume({device: "/dev/sda1", instance_id: instance_id, volume_id: ROOT_VOLUME_ID})

        # attach the home volume
        @client.attach_volume({device: "/dev/sdh", instance_id: instance_id, volume_id: HOME_VOLUME_ID})
        attached = true
      rescue Aws::EC2::Errors::IncorrectState
        "Sleeping to wait for instance to stop..."
        sleep 10
      end
    end
  end
end
