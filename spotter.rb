require "aws-sdk"
require "dotenv"
require "byebug"


Dotenv.load

class Spotter
  INSTANCE_TYPE = "t3.xlarge"
  AMI = "ami-0ca94f9bee6b10fd4"
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
      type: "one-time",
    })

    byebug
    sleep 0
  end
end

pp Spotter.new.get_spot_instance
