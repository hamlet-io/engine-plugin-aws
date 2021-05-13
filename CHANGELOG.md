# [0.0.0](https://github.com/hamlet-io/engine-plugin-aws/compare/8.1.2...0.0.0) (2021-05-13)



## [8.1.2](https://github.com/hamlet-io/engine-plugin-aws/compare/v8.0.1...8.1.2) (2021-05-13)


### Bug Fixes

* **adaptor:** handler image source build unit ([08ce16c](https://github.com/hamlet-io/engine-plugin-aws/commit/08ce16ca49762534c456e3cbfcc1c9df50d0e848))
* **apigateway:** use correct link for CA lookup ([351b590](https://github.com/hamlet-io/engine-plugin-aws/commit/351b5902bb0d5af7d260ff51a8b10aeed2eb0f33))
* **computecluster:** remove wait resources ([#302](https://github.com/hamlet-io/engine-plugin-aws/issues/302)) ([926432d](https://github.com/hamlet-io/engine-plugin-aws/commit/926432de7f8145944c0a9c77f468d851e992a550))
* **ecs:** service capacity provider usage ([466907b](https://github.com/hamlet-io/engine-plugin-aws/commit/466907bba994e8a9abad9085602f964ad061fc7c))
*  typo in attribute set type ([98374b1](https://github.com/hamlet-io/engine-plugin-aws/commit/98374b1cec40fb4283730952ce6517438d0f6524))
* alias and rename of macro for init ([22e2081](https://github.com/hamlet-io/engine-plugin-aws/commit/22e208115cc7f6d6d51add5b7f619ae9a2ad6c23))
* dynamic cmdb loading ([#286](https://github.com/hamlet-io/engine-plugin-aws/issues/286)) ([e645735](https://github.com/hamlet-io/engine-plugin-aws/commit/e6457350f7fb3b48a4cce7574de4a9fd4b4296a8))
* enable fifo on dlq ([c86f711](https://github.com/hamlet-io/engine-plugin-aws/commit/c86f711dad4f6ee36ae661973e1835e2c81c060e))
* handle naming changes for alerts ([8afae7b](https://github.com/hamlet-io/engine-plugin-aws/commit/8afae7b6fc52bcff78491ebb59a19511cc4076e2))
* link processing in awslinux vpx lb extension ([#288](https://github.com/hamlet-io/engine-plugin-aws/issues/288)) ([7b1dac3](https://github.com/hamlet-io/engine-plugin-aws/commit/7b1dac3e3787522c2b0dc734e1b58dd39fd21712))
* make env available to non-login sessions ([6604980](https://github.com/hamlet-io/engine-plugin-aws/commit/6604980a2406a73d4d2334529dc63292690505cc))
* MTA component SES config detection ([#289](https://github.com/hamlet-io/engine-plugin-aws/issues/289)) ([cd9d066](https://github.com/hamlet-io/engine-plugin-aws/commit/cd9d06697c3b918be53a91cdc8059575768c273a))
* pseudo stacks ([#268](https://github.com/hamlet-io/engine-plugin-aws/issues/268)) ([228eb07](https://github.com/hamlet-io/engine-plugin-aws/commit/228eb07c6589d025e7575f83c77560ec85a64475))
* remove debug statement ([b288db2](https://github.com/hamlet-io/engine-plugin-aws/commit/b288db2e4c76d40cc49e5adc6b63d2d36902fab5))
* set engine dir ([0496725](https://github.com/hamlet-io/engine-plugin-aws/commit/04967256734ce8adc5a87c1300f06f5e36254382))
* test outputs for capacity provider ([3b7d23a](https://github.com/hamlet-io/engine-plugin-aws/commit/3b7d23a06f54af295ab807179f5fae0d3cb15f4e))
* testing alignment ([3ab8a63](https://github.com/hamlet-io/engine-plugin-aws/commit/3ab8a63cfb88f5de96d4be6ea6ed6014f2318046))
* update ec2 support in cfn ([4dc4895](https://github.com/hamlet-io/engine-plugin-aws/commit/4dc4895e2d448b762ae034b68048e3cd7f0d31e9))
* **ec2:** compute task lookup location ([#285](https://github.com/hamlet-io/engine-plugin-aws/issues/285)) ([378be01](https://github.com/hamlet-io/engine-plugin-aws/commit/378be015414514b710fa16190f424a2a9d425fca))
* **ec2:** param options for compute tasks ([#287](https://github.com/hamlet-io/engine-plugin-aws/issues/287)) ([78ba39e](https://github.com/hamlet-io/engine-plugin-aws/commit/78ba39eaf8864744ad26b97b37bd861bae599e73))
* **ssh:** append a new line after each public key ([#278](https://github.com/hamlet-io/engine-plugin-aws/issues/278)) ([cd626e8](https://github.com/hamlet-io/engine-plugin-aws/commit/cd626e8f6dd7a5a01672b9f768a2849ac36f0d79))
* source details for ami ([cf28a46](https://github.com/hamlet-io/engine-plugin-aws/commit/cf28a463cd79af77d9d1a7f29bcc42317b736280))
* use autoscale group name for autoscale group ([62d0edc](https://github.com/hamlet-io/engine-plugin-aws/commit/62d0edc57102966c50f48d3c84f6b6dbc00935b4))
* workaround for shared changes ([4905a11](https://github.com/hamlet-io/engine-plugin-aws/commit/4905a11bdf91f35398e546e07a8a7ad7e7d51f9e))
* workaround os removal ([148f024](https://github.com/hamlet-io/engine-plugin-aws/commit/148f02460a82c2471afa26bfa1d63397c168f39c))
* workaround removed properties ([4e7f6c8](https://github.com/hamlet-io/engine-plugin-aws/commit/4e7f6c890fe0234e935e49af3797acb598fde586))
* **ec2:** typo in mount point check ([#270](https://github.com/hamlet-io/engine-plugin-aws/issues/270)) ([96ea133](https://github.com/hamlet-io/engine-plugin-aws/commit/96ea133d1e4d802b1b07505c4bdce74174ffe80d))
* **template:** change to virtual hosted s3 path ([2bedeca](https://github.com/hamlet-io/engine-plugin-aws/commit/2bedecab0929058ab9b54f7995d2b9b96958ebcd))


### Features

* **adaptor:** support for adaptor attributes ([1f55942](https://github.com/hamlet-io/engine-plugin-aws/commit/1f55942c45314defbcb021d52c2014d19b3a9de7))
* **apigateway:** mutualTLS support ([dc99916](https://github.com/hamlet-io/engine-plugin-aws/commit/dc9991665f4192ad3133426dba3690e12cb6efea))
* **apigateway:** opeanpi fragment and vpclink ([27dd240](https://github.com/hamlet-io/engine-plugin-aws/commit/27dd240b09cec743635f65b0b5f0a3ce1496f323))
* **computecluster:** add image source support ([b76005b](https://github.com/hamlet-io/engine-plugin-aws/commit/b76005b6a6cf43e567b4cf095b9ef36b16506047))
* **ec2:** adds support for autoscale lifecycles ([84fd006](https://github.com/hamlet-io/engine-plugin-aws/commit/84fd00643e30a5dee4b966eedf5235caf230cb68))
* **ec2:** handle post tasks for ec2 ([278166f](https://github.com/hamlet-io/engine-plugin-aws/commit/278166f641e2538c70447b34b806e57dd6764368))
* **ecs:** align with latest aws features ([5ab6cb3](https://github.com/hamlet-io/engine-plugin-aws/commit/5ab6cb3e5b47ad6542455f25aac387281fc4d2da))
* **globadb:** support for change streams ([d78b842](https://github.com/hamlet-io/engine-plugin-aws/commit/d78b842fb84e0513fd2faf9d02ef0313506265cb))
* add basic tests for computecluster ([945660b](https://github.com/hamlet-io/engine-plugin-aws/commit/945660bc7170fd6a9635fd120bcebfc500fdcfbb))
* add ec2 image source support for aws ([70af0ac](https://github.com/hamlet-io/engine-plugin-aws/commit/70af0ac3836c11f81ccdae23d726eb577ad0a25b))
* add support for API Gateway VPC link ([e1ab21d](https://github.com/hamlet-io/engine-plugin-aws/commit/e1ab21dff24ab303a4ad89823efaaa3eda390cde))
* add support for creating vpclinks on lb ([dcf98fb](https://github.com/hamlet-io/engine-plugin-aws/commit/dcf98fb4181db1a7caf3a6c67291772609a1ee88))
* adds support for healthchecks ([43563e8](https://github.com/hamlet-io/engine-plugin-aws/commit/43563e8f506a2e6a1d45990ddb928f1e82bbfea1))
* aws compute task implementations ([3c1b133](https://github.com/hamlet-io/engine-plugin-aws/commit/3c1b1337fb55f8b06d2e7846da7d9936f5986999))
* AWS image source attribute sets ([ab56bdb](https://github.com/hamlet-io/engine-plugin-aws/commit/ab56bdb09b29b3bb1e7aea44c65806fe6b9a0799))
* awslinux2 support for ec2 instances ([#276](https://github.com/hamlet-io/engine-plugin-aws/issues/276)) ([d55f73c](https://github.com/hamlet-io/engine-plugin-aws/commit/d55f73c95b2f3e14b01392c33f2f33a73eaeb4e3))
* base permissions policies for ec2 ([e480f75](https://github.com/hamlet-io/engine-plugin-aws/commit/e480f75b64a42f80db07244d3a9d08a3262ab18e))
* Cloudformation parameter support ([#262](https://github.com/hamlet-io/engine-plugin-aws/issues/262)) ([d89c0e5](https://github.com/hamlet-io/engine-plugin-aws/commit/d89c0e5beee75078be17b9dfa5fe5520c9a68b38))
* private bastion ([#166](https://github.com/hamlet-io/engine-plugin-aws/issues/166)) ([00920f2](https://github.com/hamlet-io/engine-plugin-aws/commit/00920f23b24c67b870de749b8d92302caeba5022))
* set healthcheck as default monitor ([006094d](https://github.com/hamlet-io/engine-plugin-aws/commit/006094da1db4232c4950ed2665fb2c05ca037b10))
* **apigateway:** Image sourcing ([#267](https://github.com/hamlet-io/engine-plugin-aws/issues/267)) ([91002a3](https://github.com/hamlet-io/engine-plugin-aws/commit/91002a3c6b84b92931a0d25a4c6b0b130a420ee0))
* **baseline:** add invoke inbound policy for data ([#263](https://github.com/hamlet-io/engine-plugin-aws/issues/263)) ([e98bf3c](https://github.com/hamlet-io/engine-plugin-aws/commit/e98bf3c378f019527eb77860056a2510eb041d68))
* **cd:** setup latest hamlet on each run ([2422627](https://github.com/hamlet-io/engine-plugin-aws/commit/242262718e7978c9d5fab4e732fb0f46bc551f8c))
* **sqs:** ordering configuration for queues ([67886c8](https://github.com/hamlet-io/engine-plugin-aws/commit/67886c88a36177e8f79875ab7218de7a21e0d7d8))



## [8.0.1](https://github.com/hamlet-io/engine-plugin-aws/compare/v8.0.0...v8.0.1) (2021-03-18)


### Bug Fixes

* better control of opsdata encryption ([783ec2e](https://github.com/hamlet-io/engine-plugin-aws/commit/783ec2e6130707bc752331b08119ebac82135435))
* invalid config handling for db ([#249](https://github.com/hamlet-io/engine-plugin-aws/issues/249)) ([da7a854](https://github.com/hamlet-io/engine-plugin-aws/commit/da7a854dff690c4aaadcfbd738ec2b20797bbf5b))
* test args for hamlet cmds ([#248](https://github.com/hamlet-io/engine-plugin-aws/issues/248)) ([c768b56](https://github.com/hamlet-io/engine-plugin-aws/commit/c768b56aec6d0ea49bec1a20208d47f8344f6431))
* **apigateway:** throttle handling for apigw ([b87fa52](https://github.com/hamlet-io/engine-plugin-aws/commit/b87fa52b4df9279f960105ca18bbd9534f791675))
* correct a number of reference attributes ([d054a19](https://github.com/hamlet-io/engine-plugin-aws/commit/d054a195bad6d8c08db249f1c96f657d30a51670))
* firehose encryption policy ([ef8cd8d](https://github.com/hamlet-io/engine-plugin-aws/commit/ef8cd8dc1955a124b68faeb40b3ee476fae0d44e))
* flowlog tidyup ([fea2fef](https://github.com/hamlet-io/engine-plugin-aws/commit/fea2fef6049c1b928dd83ad8b1d0298a92822ffa))
* masterdata object validation errors ([166bc11](https://github.com/hamlet-io/engine-plugin-aws/commit/166bc115e7baf46875b66a4b5d4ea761b5f3cf76))
* **baselinekey:** update permissions for SES ([#231](https://github.com/hamlet-io/engine-plugin-aws/issues/231)) ([50a38d9](https://github.com/hamlet-io/engine-plugin-aws/commit/50a38d948f3c3c4c6eeb613286d583891d472125))
* **bastion:** support active config on component ([#234](https://github.com/hamlet-io/engine-plugin-aws/issues/234)) ([881072c](https://github.com/hamlet-io/engine-plugin-aws/commit/881072c5c56082034bf8392a4c69b3fda5e88930))
* permission on globaldb secopndary indexes ([45bc79d](https://github.com/hamlet-io/engine-plugin-aws/commit/45bc79dd6251e196728ccaff89367c9a4225886f))
* remove unnecessary sudo ([d556173](https://github.com/hamlet-io/engine-plugin-aws/commit/d556173b260df6d7d30c12fea9eab17bb4553493))
* **s3:** do not validate replica sequence on delete ([3643173](https://github.com/hamlet-io/engine-plugin-aws/commit/364317323e449981e013e609c4a48546e3ba439b))
* **s3:** s3event to lambda fixes ([1aef1f1](https://github.com/hamlet-io/engine-plugin-aws/commit/1aef1f1f8c18f6d2992f5cbc56ffab9a7a358c0f))


### Features

* **ec2:** refactor getInitConfigSSHPublicKeys method ([32cfcfd](https://github.com/hamlet-io/engine-plugin-aws/commit/32cfcfd282db407dce849e55fb8deb2c0b11f8c8))
* **ec2:** rename an additional authorized_keys file ([b62065a](https://github.com/hamlet-io/engine-plugin-aws/commit/b62065aeb7fad6a1071d2cd94af4ccb42261ab76))
* **ec2:** SSH Key Import to ec2 instances ([096a8eb](https://github.com/hamlet-io/engine-plugin-aws/commit/096a8eb890a4e991e585d73df47825b7435b699f)), closes [hamlet-io/engine#1489](https://github.com/hamlet-io/engine/issues/1489)
* **federatedrole:** support for env in assignemnts ([#217](https://github.com/hamlet-io/engine-plugin-aws/issues/217)) ([773bde2](https://github.com/hamlet-io/engine-plugin-aws/commit/773bde2702c5108417110d132d7719dd183372a6))
* **gateway:** vpn gateway dpd action ([70b124c](https://github.com/hamlet-io/engine-plugin-aws/commit/70b124c65b4387092bc2957b7bd0692ac3200514))
* **modules:** add no_master modules ([5cc477f](https://github.com/hamlet-io/engine-plugin-aws/commit/5cc477f6ec3b08ccc9346c527893e9af437e40d1))
* **s3:** adds bucket policy for inventory ([#230](https://github.com/hamlet-io/engine-plugin-aws/issues/230)) ([eaa6fb4](https://github.com/hamlet-io/engine-plugin-aws/commit/eaa6fb4ec874fa362b0248df24b3c4d98e33d3cd))
* **s3:** extension support for bucket policy [#203](https://github.com/hamlet-io/engine-plugin-aws/issues/203) ([79a97ce](https://github.com/hamlet-io/engine-plugin-aws/commit/79a97ce253e67bc8cbc441d8cf2f1c799df89ed5))
* **template:** url image source ([#211](https://github.com/hamlet-io/engine-plugin-aws/issues/211)) ([1d1f001](https://github.com/hamlet-io/engine-plugin-aws/commit/1d1f001756f7fb3404025f5695e1c992a102be93))
* **userpool:** adds constraints for schema ([#245](https://github.com/hamlet-io/engine-plugin-aws/issues/245)) ([5407236](https://github.com/hamlet-io/engine-plugin-aws/commit/540723625724793e3ea2715dc2fcc70ee4dc00fa))
* baselinekey extensions and policy migration ([#229](https://github.com/hamlet-io/engine-plugin-aws/issues/229)) ([2f69207](https://github.com/hamlet-io/engine-plugin-aws/commit/2f69207c8a713b4a12cf98dda6c363303258e823))
* input seeders ([#236](https://github.com/hamlet-io/engine-plugin-aws/issues/236)) ([043e86f](https://github.com/hamlet-io/engine-plugin-aws/commit/043e86f1648284261edcdad2a536f338cc515192))
* whatif input provider ([#233](https://github.com/hamlet-io/engine-plugin-aws/issues/233)) ([71b5e7a](https://github.com/hamlet-io/engine-plugin-aws/commit/71b5e7a5e3e48a1f73166ef4ba78bab2d67b0f6e))
* **s3:** inventory report support ([241c299](https://github.com/hamlet-io/engine-plugin-aws/commit/241c299df55cfbe5a34ee2d4398ac7590124d6d5))
* **spa:** image source via url ([#216](https://github.com/hamlet-io/engine-plugin-aws/issues/216)) ([d70743a](https://github.com/hamlet-io/engine-plugin-aws/commit/d70743ad009d1f612fe05eb764d5d95b58b95bec))
* **userpool:** extension support for providers ([#215](https://github.com/hamlet-io/engine-plugin-aws/issues/215)) ([e0283d6](https://github.com/hamlet-io/engine-plugin-aws/commit/e0283d65b6f4bfb4be53f89be5d072e7588e7090))


### BREAKING CHANGES

* In hamlet-io/engine#1548 the composite object model is being updated
to allow for validation of the structure - including errors when
additional parameters are present.

Testing of that has surfaced a number of incorrect objects in this
plugin that have gone unnoticed

Commit is a breaking change as - though no new functionality has been
implemented - the corrections will impact existing deployments (to
their originally intended state).



# [8.0.0](https://github.com/hamlet-io/engine-plugin-aws/compare/v7.0.0...v8.0.0) (2021-01-11)


### Bug Fixes

* add lambda attributes to context ([#202](https://github.com/hamlet-io/engine-plugin-aws/issues/202)) ([1fae11e](https://github.com/hamlet-io/engine-plugin-aws/commit/1fae11e8397fb08b883fd080bd10052b3a0625e3))
* change log generation ([c609435](https://github.com/hamlet-io/engine-plugin-aws/commit/c609435cce17df77347cb3d21610ba82241aa171))
* enable testing and check for link ([176ab93](https://github.com/hamlet-io/engine-plugin-aws/commit/176ab934b0bfb7fbb3d0efeaed3f8da96eef6146))
* prodiver id migration cleanup ([#196](https://github.com/hamlet-io/engine-plugin-aws/issues/196)) ([73f26f3](https://github.com/hamlet-io/engine-plugin-aws/commit/73f26f3ffd67e8c640076cf4740a56edac531fea))
* s3 encryption replication role ([1a6ed51](https://github.com/hamlet-io/engine-plugin-aws/commit/1a6ed519643112714138f9d069b49473c3341a20))
* set nat gateway priority for mgmt contract ([c8d8487](https://github.com/hamlet-io/engine-plugin-aws/commit/c8d8487f02201b50e407dedb0755d96f377d7a3a))
* typo in log messaage ([f190d72](https://github.com/hamlet-io/engine-plugin-aws/commit/f190d7227112a32dcf850dde8e2338d8834a67cc))
* typo in switch name ([4463824](https://github.com/hamlet-io/engine-plugin-aws/commit/4463824bf902617983296c67e153021991916e3b))
* **apigateway:** fix new deployments without stage ([a2d5b4d](https://github.com/hamlet-io/engine-plugin-aws/commit/a2d5b4d5b22903e2e663abd89499aa423267cbc7))
* **apigateway:** waf depedency on stage ([#163](https://github.com/hamlet-io/engine-plugin-aws/issues/163)) ([3788d60](https://github.com/hamlet-io/engine-plugin-aws/commit/3788d60d90376b15d387f0a67fa5e8e7731fa398))
* **baseline:** disable encryption at rest by default ([0367a93](https://github.com/hamlet-io/engine-plugin-aws/commit/0367a937cf263f48a9378bfa45a99068600ba705))
* **baseline:** use s3 encryption for opsdata ([5a644d2](https://github.com/hamlet-io/engine-plugin-aws/commit/5a644d2295c711e1e83ebbc8b46898cbec01da29))
* **consolidatelogs:** disable log fwd for datafeed ([#174](https://github.com/hamlet-io/engine-plugin-aws/issues/174)) ([8d61615](https://github.com/hamlet-io/engine-plugin-aws/commit/8d61615a8a13233cf43b965740f585ebdf372e37))
* **datafeed:** clean prefixes for s3 destinations ([#188](https://github.com/hamlet-io/engine-plugin-aws/issues/188)) ([806ce44](https://github.com/hamlet-io/engine-plugin-aws/commit/806ce44870ef69c51ecb46aad83ce9385a4fbfa0))
* **datafeed:** encryption logic and disable backup ([#175](https://github.com/hamlet-io/engine-plugin-aws/issues/175)) ([ff0e09b](https://github.com/hamlet-io/engine-plugin-aws/commit/ff0e09b795249e2c7745e9ab4aa8849f75a01eca))
* **datafeed:** use error prefix for errors ([e8f4b18](https://github.com/hamlet-io/engine-plugin-aws/commit/e8f4b188a5a9b6fd1f324d87073120034821b6c1))
* **dynamodb:** query scan permissions for read access ([#201](https://github.com/hamlet-io/engine-plugin-aws/issues/201)) ([86315bb](https://github.com/hamlet-io/engine-plugin-aws/commit/86315bb9f0e8d27de8353222074e7de0a6bb57b8))
* **ecs:** handle scale in protection during updates ([f82cf16](https://github.com/hamlet-io/engine-plugin-aws/commit/f82cf16ac3d3f336789bcdd60d17a46bc1f11642))
* **ecs:** require replacement for capacity provider scaling ([#192](https://github.com/hamlet-io/engine-plugin-aws/issues/192)) ([750cf3e](https://github.com/hamlet-io/engine-plugin-aws/commit/750cf3e3421e042504a80dd97cf6481a9441c9ac))
* **logstreaming:** fixes to logstreaming setup ([62796b8](https://github.com/hamlet-io/engine-plugin-aws/commit/62796b84e3e63ff62f5e2daaaa54a0627c17708f))
* **userpool:** set userpool region for multi region deployments ([1b5b636](https://github.com/hamlet-io/engine-plugin-aws/commit/1b5b63600962bd05491c396c86ffdd4e09a1e939))
* add description for API Gateway service role ([83f59dc](https://github.com/hamlet-io/engine-plugin-aws/commit/83f59dcabaf395ac5c3ffbb614628d30250d8e01))
* add descriptions to service linked roles ([2c7664b](https://github.com/hamlet-io/engine-plugin-aws/commit/2c7664bca126fd6981298a55fae97ddb55fb58d0))
* align testcases with scenerios config ([#149](https://github.com/hamlet-io/engine-plugin-aws/issues/149)) ([9500890](https://github.com/hamlet-io/engine-plugin-aws/commit/9500890089e2cee0df6f94079f3bc37957ab0a55))
* Allow for no patterns in apigw.json ([#124](https://github.com/hamlet-io/engine-plugin-aws/issues/124)) ([a065e22](https://github.com/hamlet-io/engine-plugin-aws/commit/a065e225cbfd36ddaf775e9fd9235c61d2b3a749))
* bastion eip subset ([54a41bf](https://github.com/hamlet-io/engine-plugin-aws/commit/54a41bfe04d7c07577f3570a15718b2308eb47fd))
* check pattern verb ([4984ea8](https://github.com/hamlet-io/engine-plugin-aws/commit/4984ea8caa53a6840f120fec558329ad7492ba4b))
* Default throttling checks ([9c18797](https://github.com/hamlet-io/engine-plugin-aws/commit/9c18797d49679dac21d4da4e0a55621663d45895))
* diagram mapping for ecs ([#145](https://github.com/hamlet-io/engine-plugin-aws/issues/145)) ([e5a24b6](https://github.com/hamlet-io/engine-plugin-aws/commit/e5a24b68242b549323c55ca69fa11d74f746de3a))
* disable cfn nag on template testing ([9c2385a](https://github.com/hamlet-io/engine-plugin-aws/commit/9c2385a86a56b08a32ec7af80800690357c09d60))
* don't delete authorizer openapi.json file ([4161114](https://github.com/hamlet-io/engine-plugin-aws/commit/4161114ab1459967c04a94264217f7807f16c4df))
* enable segment iam resource set ([#122](https://github.com/hamlet-io/engine-plugin-aws/issues/122)) ([b52f8ea](https://github.com/hamlet-io/engine-plugin-aws/commit/b52f8ead83b9dc4b5e703cddd4eb3b6d8e88d8b6))
* fail testing fast ([7a5662d](https://github.com/hamlet-io/engine-plugin-aws/commit/7a5662d3d66b2b2044d12a84168b5a5601bd1ea6))
* formatting of definition file ([1635bcf](https://github.com/hamlet-io/engine-plugin-aws/commit/1635bcf2d503cbe56a5a3a4b928900acbc1440c0))
* globaldb sortKey logic ([ce418ff](https://github.com/hamlet-io/engine-plugin-aws/commit/ce418ff7691f46778caff676d14fbd4990384785))
* inbounPorts for containers ([#151](https://github.com/hamlet-io/engine-plugin-aws/issues/151)) ([7e9b258](https://github.com/hamlet-io/engine-plugin-aws/commit/7e9b25849d7147349981408ad30cc30afb636874))
* remove check for unique regions between replicating buckets ([1abe647](https://github.com/hamlet-io/engine-plugin-aws/commit/1abe647fc03677f65bdd041ec807b84867aa3122))
* s3 event notification lookup ([#176](https://github.com/hamlet-io/engine-plugin-aws/issues/176)) ([7997dd9](https://github.com/hamlet-io/engine-plugin-aws/commit/7997dd9b8d3ff273f7cd2da15c2394b6c96cdfef))
* **awstest:** fix file comments ([c44ca3a](https://github.com/hamlet-io/engine-plugin-aws/commit/c44ca3a2c69d34e2947a066c0e95b595d42b1d17))
* **ecs:** link id for efs setup ([357ca8b](https://github.com/hamlet-io/engine-plugin-aws/commit/357ca8b048704e7e1e339c7eb4fcc94973094b24))
* **ecs:** volume driver configuration properties ([1ac6669](https://github.com/hamlet-io/engine-plugin-aws/commit/1ac6669f7143ace96b5b81a39b705ccb37917994))
* **federatedrole:** fix deployment subset check ([0ca17a9](https://github.com/hamlet-io/engine-plugin-aws/commit/0ca17a9c6b18070562f9ef9520374687922bd227))
* **filetransfer:** add support for security group updates using links ([8fac235](https://github.com/hamlet-io/engine-plugin-aws/commit/8fac23540fed7671c0e50a27c01e7d48e48ae17e))
* **iam:** typo in resource deploy check ([675d024](https://github.com/hamlet-io/engine-plugin-aws/commit/675d024aa92ecebeb9d121988fe98d76e79b311f))
* **lambda:** log watcher subscription setup ([70431d0](https://github.com/hamlet-io/engine-plugin-aws/commit/70431d00bddb3a93288d17b85ab117989e629028))
* **lb:** fix logging setup process ([#159](https://github.com/hamlet-io/engine-plugin-aws/issues/159)) ([2a18dff](https://github.com/hamlet-io/engine-plugin-aws/commit/2a18dfffba4efa9f69e1100f2eea46aca48b9ea7))
* **networkacl:** use the id instead of existing ref for lookups ([d4602bc](https://github.com/hamlet-io/engine-plugin-aws/commit/d4602bc590c8991e1dda5430af105bdbdeb66c2e))
* enable concurrent builds and remove build wait ([3acd7be](https://github.com/hamlet-io/engine-plugin-aws/commit/3acd7be9c3f139c13aac817e841a9f4f3a2cfbff))
* integration patterns into explicit method path throttles ([52ac249](https://github.com/hamlet-io/engine-plugin-aws/commit/52ac249c47cd35f8e48c94fd396d6aa5a0cd1f5a))
* only add resource sets for aws ([eb4e4a6](https://github.com/hamlet-io/engine-plugin-aws/commit/eb4e4a6b2aee323a0f0165c5fdad143a63583372))
* only alert on notifications in S3 template ([9c52397](https://github.com/hamlet-io/engine-plugin-aws/commit/9c523979a1f056ea67d8ad0d5ac61f8dabb40104))
* only check patterns for method settings if throttling set ([9daa887](https://github.com/hamlet-io/engine-plugin-aws/commit/9daa8873cacd933af3b19f0b5945196c440c2e8d))
* remove unnecessary check around methodSettings ([ac57c49](https://github.com/hamlet-io/engine-plugin-aws/commit/ac57c49d56170d76bb75454430ef39fb5cc13931))
* spa state handles no baseline ([#136](https://github.com/hamlet-io/engine-plugin-aws/issues/136)) ([f5e7574](https://github.com/hamlet-io/engine-plugin-aws/commit/f5e757498cd67637003612fc002a920ffde62f3b))
* **bastion:** networkprofile for bastion links ([c65d7d4](https://github.com/hamlet-io/engine-plugin-aws/commit/c65d7d450fd03d4a5a3dcfe2cf3289a9ea3e176d))
* **bastion:** publicRouteTable  default value ([cb050f6](https://github.com/hamlet-io/engine-plugin-aws/commit/cb050f68b6c7ebd73f92ebbec1923666c862d9b9))
* **lb:** ensure lb name meets aws requirements ([b6925b2](https://github.com/hamlet-io/engine-plugin-aws/commit/b6925b2ad7c8b72ff61866636748da19facde3e7))
* **lb:** truncate lb name ([b87cf9e](https://github.com/hamlet-io/engine-plugin-aws/commit/b87cf9e13dbfc16a745cbbcf974393095bf30b56))
* **resourcelables:** add pregeneration subset to iam resource label ([f99d224](https://github.com/hamlet-io/engine-plugin-aws/commit/f99d224a56281fa0624ca785dc79b3166d76a5d4))
* **segment:** network deployment state lookup ([5858cd7](https://github.com/hamlet-io/engine-plugin-aws/commit/5858cd75a5b4ee511a2877c16ff0c03e338c56fa))
* **sqs:** move policy management for a queue into the component ([8238afb](https://github.com/hamlet-io/engine-plugin-aws/commit/8238afbc5e28a7f7623e0c88eeae9bb306a63e2e))
* **transfer:** security policy name property ([9571439](https://github.com/hamlet-io/engine-plugin-aws/commit/957143902e544eb8a611dd63fa14ae7784ad9929))
* Force lambda@edge to have no environment ([b259278](https://github.com/hamlet-io/engine-plugin-aws/commit/b2592789c5939de3491a7c7277888b4a64110b45))
* naming fixes for large deployments ([27939ea](https://github.com/hamlet-io/engine-plugin-aws/commit/27939ead3d337ff81af93dc96d7187ab5c8f2a1e))
* s3 encrypted bucket policy for ssm ([5aaf043](https://github.com/hamlet-io/engine-plugin-aws/commit/5aaf043f6470c102cec9804490f71eafcae62108))
* typo in function name ([5b24fc9](https://github.com/hamlet-io/engine-plugin-aws/commit/5b24fc9e4701f6c18ed187da973d19a0d3139ac9))
* **ecs:** name state for ecs service ([8d17e00](https://github.com/hamlet-io/engine-plugin-aws/commit/8d17e00ee032362b19e1691a0a8bbcf263f7c69e))
* remove cf resources check ([daf6554](https://github.com/hamlet-io/engine-plugin-aws/commit/daf6554181cd531c4aee6ae81425b010c5065e45))
* remove FullName for backwards compat ([5e153c4](https://github.com/hamlet-io/engine-plugin-aws/commit/5e153c4c1c82bb50cef4431aed7dd0e446328ac0))
* wording ([813fcd7](https://github.com/hamlet-io/engine-plugin-aws/commit/813fcd77a15fe944ef5bf792f7fb8d212db6a455))
* wording ([ddc41be](https://github.com/hamlet-io/engine-plugin-aws/commit/ddc41bec7f917af7d212592fca5b91433b931191))
* **cache:** remove networkprofile param from security group ([62baa1f](https://github.com/hamlet-io/engine-plugin-aws/commit/62baa1fdaed0255cd233b03a020480169ca26483))
* **cdn:** add behaviour for mobile ota ([a29af17](https://github.com/hamlet-io/engine-plugin-aws/commit/a29af17a669e3dbbd24b0822c851240c4cbed787))
* **cdn:** dont use s3 website endpoint in s3 backed origins ([#35](https://github.com/hamlet-io/engine-plugin-aws/issues/35)) ([3f62646](https://github.com/hamlet-io/engine-plugin-aws/commit/3f6264699c434b06db63eb5ed34a64e7e9337cce))
* **ecs:** combine inbound ports ([dbf51a2](https://github.com/hamlet-io/engine-plugin-aws/commit/dbf51a2155f6dbeb7b771cedd730a03a60ef500d))
* **efs:** networkacl lookup from parent ([9702027](https://github.com/hamlet-io/engine-plugin-aws/commit/9702027712170071fa404c0cfb33c7488cfe8cd7))
* **externalnetwork+gateway:** stack operation command ([936312f](https://github.com/hamlet-io/engine-plugin-aws/commit/936312f22d6df509ebadede2a61215888c7aa231))
* **gateway:** remove local route check for adding VPC routes ([0a5f729](https://github.com/hamlet-io/engine-plugin-aws/commit/0a5f7298815f721171fb1a8427a5d950fc7eb569))
* **gateway:** spelling typo ([28d7a88](https://github.com/hamlet-io/engine-plugin-aws/commit/28d7a885b49080b478917ea7c7e5d5a5a7bb7810))
* **gateway:** subset control for CFN resources ([ce9f235](https://github.com/hamlet-io/engine-plugin-aws/commit/ce9f235a3b90f3a1ed946be04114bf22eedcb4c2))
* **lambda:** check vpc access before creating security groups from links ([a07c59d](https://github.com/hamlet-io/engine-plugin-aws/commit/a07c59dc89db108d566ff581ce5510db5aac5bba))
* **lb:** minor fix for static targets ([00f6d5a](https://github.com/hamlet-io/engine-plugin-aws/commit/00f6d5a8fb0c1df57924fe934393d10abcfb961b))
* **lb:** remove debug ([d51bef3](https://github.com/hamlet-io/engine-plugin-aws/commit/d51bef35d7b6b9e66169a0b2ef6a15273cd0310b))
* **privateservice:** only error during subset ([6662e41](https://github.com/hamlet-io/engine-plugin-aws/commit/6662e414263a16bf59299fef80ce3e2347219e65))
* **rds:** change attribute types inline with cfn schema ([492e18d](https://github.com/hamlet-io/engine-plugin-aws/commit/492e18d7115e315b8fca2a03ed744e14c1b039ce))
* **rds:** handle string and int for size ([160733f](https://github.com/hamlet-io/engine-plugin-aws/commit/160733f13c1b64b2671baa3a0c182fa0bc01709e))
* **router:** align macro with setup ([3490dd3](https://github.com/hamlet-io/engine-plugin-aws/commit/3490dd309043c376d9b05a6c7742abc959de9cc7))
* **router:** fix id generation for resourceShare ([267e317](https://github.com/hamlet-io/engine-plugin-aws/commit/267e317e7dfb11f2eccac22a34d841f31be8197d))
* **router:** remove routetable requirement for external router ([c57be61](https://github.com/hamlet-io/engine-plugin-aws/commit/c57be61ccbea08e893f89270d8bc3e33e8db1e67))
* **s3:** fix for buckets without encryption ([ac8b7e4](https://github.com/hamlet-io/engine-plugin-aws/commit/ac8b7e4282a55210e5da84afe1e1a3ea0c49b43c))
* **tests:** mkdir not mrkdir ([47a6f13](https://github.com/hamlet-io/engine-plugin-aws/commit/47a6f13f61ed991e6c435d888f140be530051d66))
* **transitgateway:** remove dynamic tags from cfn updates ([be66174](https://github.com/hamlet-io/engine-plugin-aws/commit/be661743c095e7b678e920bcfacd7a68b5f8f8fa))
* **vpc:** Check network rule array items for content ([4708862](https://github.com/hamlet-io/engine-plugin-aws/commit/47088624c302135987b8910df31761b819ee96a5))
* **vpc:** implement explicit control on egress ([d4c41b7](https://github.com/hamlet-io/engine-plugin-aws/commit/d4c41b7997eee54694ed60f20d721a436ce42439))
* **vpc:** remove ports completey for all protocol ([9065ac2](https://github.com/hamlet-io/engine-plugin-aws/commit/9065ac251e69486389cecd025c8f3cd851a2986b))
* **vpc:** support any protocol sec group rules ([5925ad8](https://github.com/hamlet-io/engine-plugin-aws/commit/5925ad895c87de3de8c23355bb0d8b033bab9ab5))
* Auth provider configuration defaulting logic ([e498f69](https://github.com/hamlet-io/engine-plugin-aws/commit/e498f691dd62e781f166726809e75bd78fa7227f))
* check component subset for cfn resources ([f1c7120](https://github.com/hamlet-io/engine-plugin-aws/commit/f1c7120690b9cb0b6e8d0d7536da2dd32b7319b6))
* Gateway endpoint es role ([f2d6f70](https://github.com/hamlet-io/engine-plugin-aws/commit/f2d6f706dcc7871cfd9bc65da74da411145a2956))
* hamlet test generate command ([defa570](https://github.com/hamlet-io/engine-plugin-aws/commit/defa570418c9a742cf8e37cccc0d437c8d6cd576))
* init configuration ordering for ec2 ([55917f0](https://github.com/hamlet-io/engine-plugin-aws/commit/55917f05b47580900bf7fdcf1c041a45838847e1))
* Permit iam/lg pass for uncreated components ([00d1888](https://github.com/hamlet-io/engine-plugin-aws/commit/00d18883725ae4c7d06842417b3b400382571339))
* Permit iam/lg passes before component created ([5d4e82e](https://github.com/hamlet-io/engine-plugin-aws/commit/5d4e82eedecfa5c8d8999816f3d040085fcd2e03))
* security group references for security groups ([ac2fcf7](https://github.com/hamlet-io/engine-plugin-aws/commit/ac2fcf7e006d11cae808833320a0b9b43a4e6801))
* set destination ports for default private service ([ba62efa](https://github.com/hamlet-io/engine-plugin-aws/commit/ba62efa838dcdf8fd2eccbe56e9139835cbb6074))
* template testing script ([8712b11](https://github.com/hamlet-io/engine-plugin-aws/commit/8712b11b04a01cbf9ab6fc67c27a22bd9fa2cddb))
* typo in gateway and router components ([5dcb62a](https://github.com/hamlet-io/engine-plugin-aws/commit/5dcb62a571047197dafa39068c8755135535f62d))
* use mock runId for apigw resources ([2d3faf9](https://github.com/hamlet-io/engine-plugin-aws/commit/2d3faf90d9f1aa425bfb017565748e1c2f686f04))


### Code Refactoring

* align testing with entrances ([46e9c2d](https://github.com/hamlet-io/engine-plugin-aws/commit/46e9c2d851726a4647186ed9b679ef957ff778de))
* update output to align with flow support ([31f3ec8](https://github.com/hamlet-io/engine-plugin-aws/commit/31f3ec8df83c813e204951211ea0142d2edce9e7))


### Features

* add base service roles to masterdata ([fa16788](https://github.com/hamlet-io/engine-plugin-aws/commit/fa167887f4c3dea72498b7ac133b6f369522b603))
* add changelog generation ([#210](https://github.com/hamlet-io/engine-plugin-aws/issues/210)) ([bd3a290](https://github.com/hamlet-io/engine-plugin-aws/commit/bd3a290616252d87307b80368cb7991a6aaca241))
* **account:** s3 account bucket naming ([6e86ec5](https://github.com/hamlet-io/engine-plugin-aws/commit/6e86ec570e6e490fbe6ca1391e770ae60fc3c7b4))
* **alerts:** get metric dimensions from blueprint ([#193](https://github.com/hamlet-io/engine-plugin-aws/issues/193)) ([779179f](https://github.com/hamlet-io/engine-plugin-aws/commit/779179f2a386a79101eefe683f7d8779c64f0cdf))
* **amazonmq:** add support for amazonmq as a service ([5e61b75](https://github.com/hamlet-io/engine-plugin-aws/commit/5e61b75b6e1447ad9dc0da2bd76e13b6495a9813))
* **apigateway:** add quota throttling ([0464b57](https://github.com/hamlet-io/engine-plugin-aws/commit/0464b57bcac81a0194aba0f870425ad1b9418816))
* **apigateway:** allow for throttling apigatway at api, stage and method levels ([500d1e4](https://github.com/hamlet-io/engine-plugin-aws/commit/500d1e4cf219347401f9d43904e69e8bba276da2))
* **awsdiagrams:** adds diagram mappings for aws resources ([9f96230](https://github.com/hamlet-io/engine-plugin-aws/commit/9f962303f18a093075de82f9b97ff7f7f30870e0))
* **baseline:** s3 attrs on baseline data ([9369923](https://github.com/hamlet-io/engine-plugin-aws/commit/9369923ae14130c298f101f187e6b5658dd86bfd))
* **cdn:** add support for external service origins ([1a7db2d](https://github.com/hamlet-io/engine-plugin-aws/commit/1a7db2d08fca863aa1b84cd50f0352d307b26020))
* **consolidatelogs:** enable network flow log ([ac2dd22](https://github.com/hamlet-io/engine-plugin-aws/commit/ac2dd2282a72d43616df5fded393189ea0cfa094))
* **consolidatelogs:** support deployment prefixes in datafeed prefix ([c47a117](https://github.com/hamlet-io/engine-plugin-aws/commit/c47a117cd8f9036a184ccbdd8507b5efb515f53e))
* **datafeed:** support adding deployment prefixes to datafeeds ([74e76d0](https://github.com/hamlet-io/engine-plugin-aws/commit/74e76d0ec5cdac73f91aa75b62a8b273e992b39e))
* **ecs:** add hostname for a task container ([46395ce](https://github.com/hamlet-io/engine-plugin-aws/commit/46395ce19452826e542008ed2328ad949b282380))
* **ecs:** add support for efs volume mounts to tasks ([8528093](https://github.com/hamlet-io/engine-plugin-aws/commit/8528093b494ee54900dcb854c014c1ae427f765a))
* **ecs:** adds support for ulimits on tasks ([5e7b706](https://github.com/hamlet-io/engine-plugin-aws/commit/5e7b70612054b8196403f7e7ec7d7f4a91a04bd9))
* **ecs:** docker based health check support ([3817a1b](https://github.com/hamlet-io/engine-plugin-aws/commit/3817a1b25a92038ccd4ab39a5b4ce9dfbc88a959))
* **ecs:** external image sourcing ([2391e4d](https://github.com/hamlet-io/engine-plugin-aws/commit/2391e4d5999045b4bdb1f2e092c6ccb5eb498017))
* **ecs:** placement constraints ([c841460](https://github.com/hamlet-io/engine-plugin-aws/commit/c8414600a59ad590d722a3f8fec2067133d55874))
* **ecs:** use deployment group filters on ecs subcomponents ([#120](https://github.com/hamlet-io/engine-plugin-aws/issues/120)) ([6459014](https://github.com/hamlet-io/engine-plugin-aws/commit/645901457101da9a7586932c60ff0ca001adb2c9))
* **efs:** add access point provisioning and iam support ([d69b6ef](https://github.com/hamlet-io/engine-plugin-aws/commit/d69b6ef8b802fc5872515df1be4e34218439b263))
* **efs:** add iam based policies and access point creation ([78997c1](https://github.com/hamlet-io/engine-plugin-aws/commit/78997c1b978c802656f5c0a1fbb48002b64927a2))
* **efs:** add support for access point and iam mounts in ec2 components ([8c683ec](https://github.com/hamlet-io/engine-plugin-aws/commit/8c683ec8d8391e577e3cbfab9ef4959941668f2d))
* **kms:** region based arn lookup ([2540293](https://github.com/hamlet-io/engine-plugin-aws/commit/25402931237042fcf963f9b28375cb17224de992))
* **lambda:** extension version control ([3e0ab99](https://github.com/hamlet-io/engine-plugin-aws/commit/3e0ab99d6ef010075094d857f49d4eae7e242566))
* **output:** add replace function for outputs ([b9553d0](https://github.com/hamlet-io/engine-plugin-aws/commit/b9553d0289e28e10d8211ce58639a7fa1460bb38))
* **queuehost:** aws deployment support ([60a32e0](https://github.com/hamlet-io/engine-plugin-aws/commit/60a32e05f8f1083db45f901787b37bb4b9255e8f))
* **queuehost:** encrypted url and secret support ([ef8f1f3](https://github.com/hamlet-io/engine-plugin-aws/commit/ef8f1f332dcf73c39b5199c5de1ff247da31f01f))
* **queuehost:** initial testing ([f099c42](https://github.com/hamlet-io/engine-plugin-aws/commit/f099c42e74db9e108ab0a96874121abfdb66f5fd))
* add compute provider support to ecs host ([#150](https://github.com/hamlet-io/engine-plugin-aws/issues/150)) ([59ea76b](https://github.com/hamlet-io/engine-plugin-aws/commit/59ea76bbe2c786cfad38a90bc47a0bc4e48bdd79))
* authorizer lambda permissions ([7026e06](https://github.com/hamlet-io/engine-plugin-aws/commit/7026e06f4acf01a8b764b37e89fdf36029e01fdc))
* autoscale replacement updates ([65f4b45](https://github.com/hamlet-io/engine-plugin-aws/commit/65f4b457bfaa526d583643854a7e9bb4cc68c607))
* copy openapi definition file to authorizers ([#137](https://github.com/hamlet-io/engine-plugin-aws/issues/137)) ([350afda](https://github.com/hamlet-io/engine-plugin-aws/commit/350afda860638b410a1b2780e51cf4f6dc3a748e))
* enable replication from baselinedata buckets to s3 ([0c8464c](https://github.com/hamlet-io/engine-plugin-aws/commit/0c8464c51d43a69ecf4845a8db34b6945e189bd2))
* fragment to extension migration ([#194](https://github.com/hamlet-io/engine-plugin-aws/issues/194)) ([ab63e14](https://github.com/hamlet-io/engine-plugin-aws/commit/ab63e14c38787c345f53d9981d71e0f6bca428b1))
* globaldb secondary indexes ([#204](https://github.com/hamlet-io/engine-plugin-aws/issues/204)) ([629a675](https://github.com/hamlet-io/engine-plugin-aws/commit/629a6753f6b80882b78b347a9e6ba5d5d12c8cc7))
* Message Transfer Agent components ([a82fd81](https://github.com/hamlet-io/engine-plugin-aws/commit/a82fd81671a67ca333cb584a21fcd996d1b36d0f)), closes [#1499](https://github.com/hamlet-io/engine-plugin-aws/issues/1499)
* **logging:** add deploy prefixes to log collectors ([74c2116](https://github.com/hamlet-io/engine-plugin-aws/commit/74c21160bdefe6c6e391633f90f52899ab13e3d5))
* **network:** user defined network flow logs ([62d6710](https://github.com/hamlet-io/engine-plugin-aws/commit/62d6710f8f70332b12ac2998ec18d559fe46cfdc))
* **s3:** bucket replication to ext services ([#183](https://github.com/hamlet-io/engine-plugin-aws/issues/183)) ([cea9dc3](https://github.com/hamlet-io/engine-plugin-aws/commit/cea9dc34a83ae1a7440efbffc67d7df4ac7ce7d4))
* **secretstore:** secrets manager support ([#189](https://github.com/hamlet-io/engine-plugin-aws/issues/189)) ([77ea4ee](https://github.com/hamlet-io/engine-plugin-aws/commit/77ea4ee9447e0fa2c3f3e99c98a1b435b566f7a4))
* "account" and fixed build scope ([#129](https://github.com/hamlet-io/engine-plugin-aws/issues/129)) ([3fc72fc](https://github.com/hamlet-io/engine-plugin-aws/commit/3fc72fc25bb853af17e9fdc871b0f2df6c723606))
* patching via init script ([23ab462](https://github.com/hamlet-io/engine-plugin-aws/commit/23ab462a3f7cc77414666eedecb1fc471b5739ba))
* resource to service mappings ([90be99c](https://github.com/hamlet-io/engine-plugin-aws/commit/90be99ca5930c482d5d1be57ded0cb7ecfa449c8))
* slack message on pipeline fail ([c08c83f](https://github.com/hamlet-io/engine-plugin-aws/commit/c08c83f896a2a511d3264b3772e0473994ee8ec8))
* sync authorizer openapi spec with api ([f15d7f6](https://github.com/hamlet-io/engine-plugin-aws/commit/f15d7f68e0c8dd6ea23a231ea217a413a85cff5f))
* WAF logs lifecycle rule ([#164](https://github.com/hamlet-io/engine-plugin-aws/issues/164)) ([115385c](https://github.com/hamlet-io/engine-plugin-aws/commit/115385cbb2390cc345e9877d4ec53b0a1784727b))
* **apigatewa:** add TLS configuration for domain names ([ff2ac04](https://github.com/hamlet-io/engine-plugin-aws/commit/ff2ac04f0c872cb377f0b9487968be39290e1470))
* **cdn:** support links to load balancers ([30b290f](https://github.com/hamlet-io/engine-plugin-aws/commit/30b290f5e93e7908b50b9e13bf35107def253939))
* **console:** enable SSM session support for all ec2 components ([f483f02](https://github.com/hamlet-io/engine-plugin-aws/commit/f483f02d672c858ea91b9a7873e84fef66a6422f))
* **console:** service policies for ssm session manager ([00df514](https://github.com/hamlet-io/engine-plugin-aws/commit/00df514053f3c2734789bec445bc9417b02a105d))
* **ec2:** volume encryption ([797132b](https://github.com/hamlet-io/engine-plugin-aws/commit/797132b282b277e4020e00725792606dc24dfad7))
* **ecs:** fargate run task state support ([#44](https://github.com/hamlet-io/engine-plugin-aws/issues/44)) ([2400a8e](https://github.com/hamlet-io/engine-plugin-aws/commit/2400a8e4e1e611ca718c0809d9bf7bc2eb1ff718))
* **ecs:** support ingress links for security groups ([63584a6](https://github.com/hamlet-io/engine-plugin-aws/commit/63584a69a2c9c4706c8cccdd254de6c970a2db44))
* **ecs:** support udp based port mappings ([#46](https://github.com/hamlet-io/engine-plugin-aws/issues/46)) ([50c5827](https://github.com/hamlet-io/engine-plugin-aws/commit/50c5827bdc849e98e552a8c1204978d181efeb55))
* **externalnetwork:** vpn router supportf ([6fa65ab](https://github.com/hamlet-io/engine-plugin-aws/commit/6fa65ab6c0a8660c660d2b6b88aed4bb660b2130))
* **externalnetwork:** vpn support for external networks ([c1c5303](https://github.com/hamlet-io/engine-plugin-aws/commit/c1c53037cfbeb65b8bb626442af00bb107b0a5b9))
* **externalnetwork+gateway:** vpn gateway configuration options ([f23ea55](https://github.com/hamlet-io/engine-plugin-aws/commit/f23ea55b73664ad154e090a04af2a3442469cd38))
* **filetransfer:** add AWS support for filetransfer component ([77a27f7](https://github.com/hamlet-io/engine-plugin-aws/commit/77a27f728be56a58b4e8636e48f38d6ce078b52e))
* **filetransfer:** base component tests ([be6bbeb](https://github.com/hamlet-io/engine-plugin-aws/commit/be6bbeb78754542973e3957a88c5405b655d9b34))
* **filetransfer:** support for security policies ([5d8d506](https://github.com/hamlet-io/engine-plugin-aws/commit/5d8d50645571ac75e5026f45380800456b9825be))
* **gateway:** add support for destination port configuration ([#62](https://github.com/hamlet-io/engine-plugin-aws/issues/62)) ([d3046e2](https://github.com/hamlet-io/engine-plugin-aws/commit/d3046e23b9f31ee966deb4c2ca7cc7bba07fdb12))
* **gateway:** externalservice based router support ([d3743d4](https://github.com/hamlet-io/engine-plugin-aws/commit/d3743d42fe36ffa7461e1cfa938722ffc7d26ced))
* **gateway:** gateway support for the router component ([85d7856](https://github.com/hamlet-io/engine-plugin-aws/commit/85d78563999235ef07e05de6948cabca9481eecf))
* **gateway:** link based gateway support ([80de297](https://github.com/hamlet-io/engine-plugin-aws/commit/80de2976afae76859a17553697b4172b37aaad5f))
* **gateway:** private dns configuration ([f15fcc3](https://github.com/hamlet-io/engine-plugin-aws/commit/f15fcc398ad0a63f4cc87ce84bb80692c536c7a4))
* **gateway:** private gateway support ([9d1f3d1](https://github.com/hamlet-io/engine-plugin-aws/commit/9d1f3d139715d4ba03cce34e3c16a0e95ce14bd8))
* **gateway:** vpn connections to gateways ([ba80668](https://github.com/hamlet-io/engine-plugin-aws/commit/ba8066874469c69d7b5992e88325e99d9533b4c8))
* **globaldb:** initial support for the globalDb component ([#45](https://github.com/hamlet-io/engine-plugin-aws/issues/45)) ([b2131da](https://github.com/hamlet-io/engine-plugin-aws/commit/b2131da6cd61f8a2ea0258b73a12b7fb497fd0e2)), closes [hamlet-io/engine#1325](https://github.com/hamlet-io/engine/issues/1325)
* **lb:** add LB target group monitoring dimensions ([fd6c6f5](https://github.com/hamlet-io/engine-plugin-aws/commit/fd6c6f53c6160cf34c8394579bb163511d7eda0f))
* **lb:** add networkacl support for network engine ([#97](https://github.com/hamlet-io/engine-plugin-aws/issues/97)) ([a998f52](https://github.com/hamlet-io/engine-plugin-aws/commit/a998f520deebfa87d98ac9b2066e0949623c1f0c))
* **lb:** waf support for application lb ([4c2bb81](https://github.com/hamlet-io/engine-plugin-aws/commit/4c2bb812e61e21a3021e4ef52b4b7cdf15c5203e))
* **s3:** Add resource support for S3 Encryption ([b764ef4](https://github.com/hamlet-io/engine-plugin-aws/commit/b764ef4e4fcbf36b5bd6eb65b8a39b016abd08be))
* **ssm:** supports the use of a dedicated CMK for console access ([07df737](https://github.com/hamlet-io/engine-plugin-aws/commit/07df7371181c9a490396a5e7dbb1c373e1daf530))
* **waf:** enable log waf logging for waf enabled services ([2c0db35](https://github.com/hamlet-io/engine-plugin-aws/commit/2c0db35324e8b7b01af2f31381c7c4c5d445a373))
* add bastion to default network profile ([0ec60a5](https://github.com/hamlet-io/engine-plugin-aws/commit/0ec60a5563dac7b0215d424b9b1a0cee1f8ecd42))
* ingress/egress security group control ([d27a2da](https://github.com/hamlet-io/engine-plugin-aws/commit/d27a2dab4cd4ebb7da7512f78cd37f648fd5af45))
* resource labels ([33d95b5](https://github.com/hamlet-io/engine-plugin-aws/commit/33d95b52591caa8d11225f71b5fe9a02ebef36d7))
* **lb:** static targets ([978176b](https://github.com/hamlet-io/engine-plugin-aws/commit/978176b1cebfe29ce8f40a6241e8eb2930ee30d7))
* **lb:** Support for Network load balancer TLS offload ([9410653](https://github.com/hamlet-io/engine-plugin-aws/commit/941065349b5ccd75a81f17faca4722c5e109d400))
* **mobileapp:** OTA CDN on Routes ([9c87a7a](https://github.com/hamlet-io/engine-plugin-aws/commit/9c87a7af1a53764c2ab7fe09dfc305b0f9cf6bb4))
* **privateservice:** initial implementation ([#50](https://github.com/hamlet-io/engine-plugin-aws/issues/50)) ([8c0d4a9](https://github.com/hamlet-io/engine-plugin-aws/commit/8c0d4a986562b938fb6f16e55d82aba67d8d30f6))
* **router:** add resource sharing between aws accounts ([bc4bfac](https://github.com/hamlet-io/engine-plugin-aws/commit/bc4bfaca5db5c7caa346d73a6a386b262f666f21))
* **router:** always set BGP ASN ([a96f55b](https://github.com/hamlet-io/engine-plugin-aws/commit/a96f55bece46fb20cfd1a455146063b1bfdad51f))
* **router:** initial support for router component in aws ([6b12992](https://github.com/hamlet-io/engine-plugin-aws/commit/6b12992042d0e8d0a5f644f1314447d7299e0b04))
* **router:** support for static routes ([3bb7ebb](https://github.com/hamlet-io/engine-plugin-aws/commit/3bb7ebb1338b1168f559807f7e1055cd384644b0))
* **s3:** cdn list support for s3 ([38bc00a](https://github.com/hamlet-io/engine-plugin-aws/commit/38bc00aa9f8cc0da1f868639df6c13aa721e6220))
* **s3:** enable at rest-encryption on buckets ([cae9034](https://github.com/hamlet-io/engine-plugin-aws/commit/cae90343fde72cf8cd58414acf9f5db594b08d34))
* **s3:** KMS permissions for S3 bucket access ([2953851](https://github.com/hamlet-io/engine-plugin-aws/commit/2953851db4c4fc7b1e9c741989e020cced9e5bc6))
* **service:** add support for transitgateway resources ([b860756](https://github.com/hamlet-io/engine-plugin-aws/commit/b86075695e641266559792aadd03456cddb6f534))
* **userpool:** disable oauth on clients ([fee17ce](https://github.com/hamlet-io/engine-plugin-aws/commit/fee17cece8b826bf8e9ad2f276ae208e75dada27))
* **userpool:** get client secret on deploy ([0fe769f](https://github.com/hamlet-io/engine-plugin-aws/commit/0fe769fbf899254af06eae98144f0cf49049fb63))
* **vpc:** security group rules - links profiles ([2f4eb4f](https://github.com/hamlet-io/engine-plugin-aws/commit/2f4eb4fda1ce657a21b325fe8f9f44945f630d81))
* Enhanced checks on userpool auth provider names ([#34](https://github.com/hamlet-io/engine-plugin-aws/issues/34)) ([59c80aa](https://github.com/hamlet-io/engine-plugin-aws/commit/59c80aa2b0a69a637c4ef352de90ef6a76fbf065))


* <refactor> Update component setup macros naming ([9377bcd](https://github.com/hamlet-io/engine-plugin-aws/commit/9377bcdd6f9bd1eaef75e503487b2265583c5258))


### BREAKING CHANGES

* requires entrances support in the engine
* aligns with the new entrances and flows support from
the engine
* this change aligns component macros with the new
format



# [6.0.0](https://github.com/hamlet-io/engine-plugin-aws/compare/v5.4.0...v6.0.0) (2019-09-13)



# [5.4.0](https://github.com/hamlet-io/engine-plugin-aws/compare/v5.3.1...v5.4.0) (2019-03-06)



## [5.3.1](https://github.com/hamlet-io/engine-plugin-aws/compare/v5.3.0...v5.3.1) (2018-11-16)



# [5.3.0](https://github.com/hamlet-io/engine-plugin-aws/compare/v5.3.0-rc1...v5.3.0) (2018-11-15)



# [5.3.0-rc1](https://github.com/hamlet-io/engine-plugin-aws/compare/v5.2.0-rc3...v5.3.0-rc1) (2018-10-23)



# [5.2.0-rc3](https://github.com/hamlet-io/engine-plugin-aws/compare/v5.2.0-rc2...v5.2.0-rc3) (2018-07-12)



# [5.2.0-rc2](https://github.com/hamlet-io/engine-plugin-aws/compare/v5.2.0-rc1...v5.2.0-rc2) (2018-06-21)



# [5.2.0-rc1](https://github.com/hamlet-io/engine-plugin-aws/compare/v5.1.0...v5.2.0-rc1) (2018-06-19)



# [5.1.0](https://github.com/hamlet-io/engine-plugin-aws/compare/v4.3.10...v5.1.0) (2018-05-22)



## [4.3.10](https://github.com/hamlet-io/engine-plugin-aws/compare/v4.3.9...v4.3.10) (2017-09-17)



## [4.3.9](https://github.com/hamlet-io/engine-plugin-aws/compare/v4.3.8...v4.3.9) (2017-05-13)



## [4.3.8](https://github.com/hamlet-io/engine-plugin-aws/compare/v4.3.7...v4.3.8) (2017-05-10)



## [4.3.7](https://github.com/hamlet-io/engine-plugin-aws/compare/v4.3.6...v4.3.7) (2017-05-08)



## [4.3.6](https://github.com/hamlet-io/engine-plugin-aws/compare/v4.3.5...v4.3.6) (2017-05-07)



## [4.3.5](https://github.com/hamlet-io/engine-plugin-aws/compare/v4.3.4...v4.3.5) (2017-05-04)



## [4.3.4](https://github.com/hamlet-io/engine-plugin-aws/compare/v4.3.3...v4.3.4) (2017-05-04)



## [4.3.3](https://github.com/hamlet-io/engine-plugin-aws/compare/v4.3.2...v4.3.3) (2017-05-04)



## [4.3.2](https://github.com/hamlet-io/engine-plugin-aws/compare/v4.3.1...v4.3.2) (2017-04-28)



## [4.3.1](https://github.com/hamlet-io/engine-plugin-aws/compare/v4.1.1...v4.3.1) (2017-03-26)



## 4.1.1 (2017-02-03)



