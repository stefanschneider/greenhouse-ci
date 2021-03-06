#!/usr/bin/env ruby

require_relative './cloudformation_template'
require 'aws/cloud_formation'
require 'uri'

def delete_stack(name)
  puts "deleting stack #{name}"
  stack = $cfm.stacks[name]
  stack.delete
  while stack.exists? do
    puts "waiting for stack to be destroyed"
    sleep(10)
  end
end

def create_stack(name, template, parameters)
  puts "creating stack #{name}"
  $cfm.stacks.create(name, template, disable_rollback: true, parameters: parameters)
end

def wait_for_stack(name)
  stack = $cfm.stacks[name]
  status = stack.status
  while status != "CREATE_COMPLETE"
    raise "Create failed, #{status}" if status != "CREATE_IN_PROGRESS"
    puts "waiting for stack to complete"
    sleep(10)
    status = stack.status
  end
end

$cfm = AWS::CloudFormation.new(access_key_id: ENV["AWS_ACCESS_KEY_ID"],
                               secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"])

delete_stack(ENV["STACKNAME"])

template = CloudformationTemplate.new(template_json: File.read("diego-windows-release/cloudformation.json.template"))
template.generator_url = File.read("greenhouse-install-script-generator-file/url")
template.diego_windows_msi_url = File.read("diego-windows-msi-file/url")
template.garden_windows_msi_url = File.read("garden-windows-msi-file/url")
setup_url = File.read("garden-windows-msi-file/url").gsub(/GardenWindows-(.*)\.msi/, "setup-\\1.ps1")
template.setup_url = setup_url

create_stack(ENV["STACKNAME"], template.to_json, {
  BoshHost: ENV.fetch("BOSH_HOST"),
  BoshPassword: ENV.fetch("BOSH_PASSWORD"),
  BoshUserName: ENV.fetch("BOSH_USER"),
  CellName: ENV["CELL_NAME"],
  ContainerizerPassword: ENV.fetch("CONTAINERIZER_PASSWORD"),
  SecurityGroup: ENV.fetch("SECURITY_GROUP"),
  SubnetCIDR: ENV.fetch("SUBNET_CIDR"),
  NATZ: ENV.fetch("NATZ_ID"),
  VPCID: ENV.fetch("VPC_ID")
})

wait_for_stack(ENV["STACKNAME"])
