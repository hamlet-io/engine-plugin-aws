#!/usr/bin/env bash

profile="$1"; shift

[[ -z "${profile}" ]] && echo -e "\nScript requires a profile as the first parameter to use when querying AWS" && exit 1

# Ignore the directory used to collect the data
[[ ! -f .gitignore ]] && echo "amis/" > .gitignore

if [[ ! -d amis ]]; then
  mkdir -p amis/nat
  mkdir -p amis/ec2
  mkdir -p amis/ecs
fi

# List of regions
readarray -t regions <<< "$(aws --profile "${profile}" --region us-east-1 ec2 describe-regions --query 'Regions[].[RegionName]' --output text | sort)"

# Find AMIs for each region
declare -A nat_amis
declare -A ec2_amis
declare -A ecs_amis

for region in "${regions[@]}"; do
  aws --profile "${profile}" --region "${region}" ec2 describe-images --owners amazon --filters 'Name=name,Values=amzn-ami-vpc-nat-hvm-????.??.*x86_64-ebs' > "amis/nat/${region}.json"
  nat_amis["${region}"]="$(jq -r ".Images | sort_by(.CreationDate) | last(.[]).ImageId | select(.!=null)" < "amis/nat/${region}.json")"

  aws --profile "${profile}" --region "${region}" ec2 describe-images --owners amazon --filters 'Name=name,Values=amzn-ami-hvm-????.??.*x86_64-gp2' > "amis/ec2/${region}.json"
  ec2_amis["${region}"]="$(jq -r ".Images | sort_by(.CreationDate) | last(.[]).ImageId | select(.!=null)" < "amis/ec2/${region}.json")"

  aws --profile "${profile}" --region "${region}" ec2 describe-images --owners amazon --filters 'Name=name,Values=amzn-ami-????.??.*-amazon-ecs-optimized' > "amis/ecs/${region}.json"
  ecs_amis["${region}"]="$(jq -r ".Images | sort_by(.CreationDate) | last(.[]).ImageId | select(.!=null)" < "amis/ecs/${region}.json")"

  jq -n --arg region "${region}" --arg nat "${nat_amis[${region}]}" --arg ec2 "${ec2_amis[${region}]}" --arg ecs "${ecs_amis[${region}]}" \
    '{ ($region) : {"AMIs" : {"Centos" : {"NAT" : $nat, "EC2" : $ec2, "ECS" : $ecs}}}}' > "amis/${region}.json"

  echo "${region}" "${nat_amis[${region}]}" "${ec2_amis[${region}]}" "${ecs_amis[${region}]}"
done


# Merge with current master file
echo "Generating master data ftl file ..."

jq --indent 4 '.' regions.json > amis/old_regions.json
index=0
filter=".[${index}]"
files=("amis/old_regions.json")
for region in "${regions[@]}"; do
  index=$(( $index + 1 ))
  filter="${filter} * .[$index]"
  files+=("amis/${region}.json")
done

jq --indent 4 -s "${filter}" "${files[@]}" > amis/new_regions.json

diff amis/old_regions.json amis/new_regions.json > /dev/null 2>&1; result=$?
if [[ ${result} -ne 0 ]]; then
  cp amis/new_regions.json regions.json
fi
