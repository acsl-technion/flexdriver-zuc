# Setup the desired script and output directories
# These paths need to be updated to match your environment
set projDir             "."
set synthDir            $projDir/Synth
set implDir             $projDir/Implement
set bitDir              $projDir/Bitstreams
set runSummary          $projDir/run_summary.log
set script_path         [ file dirname [ info script ] ]
set srcDir              $script_path/src

# PCIe Example design information. This should be updated to match
# your design.
set part                xcku15p-ffve1517-2-i
set topModuleName       zuc_top 

# Steps for the update version of the design dependent on having completed previous step.
set runSynth            1
set runImpl             1
set runBitstreams       1

if { $runSynth } {

  # Create the output directory and delete the previously generated files.
  if {[file isdir $synthDir]} {
    file delete -force $synthDir
  }
  file mkdir $synthDir
  
  
  puts "# HD INFO: Running synthesis"
  
  # Create an in-memory project
  create_project -in_memory -part $part
  
  # Add the required source files for this version of the example module.
  # This includes all files necessary for compiling this version of the example module.
  # This should be updated as desired for user application.
  add_files [ glob $srcDir/*.v ]
  
  # Add any IP xci file
  set src_ip_dir  $projDir/ip
  set xci_files [glob -nocomplain $srcDir/*.xci]
  foreach File $xci_files {
    set file_name [file tail [file rootname $File]]
    if {![file isdir $src_ip_dir/$file_name]} {
      file mkdir $src_ip_dir/$file_name
    }
    file copy -force $srcDir/$file_name.xci $src_ip_dir/$file_name/. 
    # Add the IP .xci file.
    add_files $src_ip_dir/$file_name/$file_name.xci
    if {[get_property generate_synth_checkpoint [get_files $src_ip_dir/$file_name/$file_name.xci]]} {
      if {![file exists $src_ip_dir/$file_name/$file_name.dcp]} {
        synth_ip [get_files $src_ip_dir/$file_name/$file_name.xci] > $src_ip_dir/$file_name/$file_name.log
      }
    } else {
      # Generate the IP if needed.
      generate_target all [get_files $src_ip_dir/$file_name/$file_name.xci] > $src_ip_dir/$file_name/$file_name.log
    }
  }
  
  # Read in synthesis constraints
  set xdc_files [glob -nocomplain $srcDir/*.xdc]
  foreach File $xdc_files {
    add_files $File
  }

  # Read Mellanox-FLC dcp.
  set flc_dcp_file      $srcDir/flc.dcp
  if {![file isfile $flc_dcp_file]} {
    exit
  }
  add_files $flc_dcp_file

  update_compile_order -fileset sources_1
  
  # Run synthesis.
  synth_design -top $topModuleName -part $part > $synthDir/${topModuleName}_synth_design.log
  # Create the synthesized checkpoint.
  write_checkpoint -force $synthDir/${topModuleName}_synth.dcp
  
  # Close the in memory project that was created.
  close_project
}



if { $runImpl } {

  # Create the output directory and remove previously generated files.
  if {[file isdir $implDir]} {
    file delete -force $implDir
  }
  file mkdir $implDir
  
  puts "# HD INFO: Running implementation"
  
  # Create an in-memory project
  create_project -in_memory -part $part
  
  # Read in the  synth.dcp and associate it with the appropriate hierarchy
  set synth_dcp         $synthDir/${topModuleName}_synth.dcp
  if {![file isfile $synth_dcp]} {
    exit
  }
  open_checkpoint $synth_dcp
  
  ## Read in implementation constraints
  set xdc_files [glob -nocomplain $srcDir/*.xdc]
  foreach File $xdc_files {
    add_files $File
  }
  
  # Run the desired implementation steps. Additional implementation steps and
  # options can be added here as desired. A checkpoint is written after each
  # step for convenience.
#   opt_design > $implDir/${topModuleName}_opt_design.log
#  opt_design -verbose -directive Explore > $implDir/${topModuleName}_opt_design.log
  opt_design -directive Explore > $implDir/${topModuleName}_opt_design.log

  write_checkpoint -force $implDir/${topModuleName}_opt_design.dcp
#  place_design > $implDir/${topModuleName}_place_design.log
#  place_design -directive Explore > $implDir/${topModuleName}_place_design.log
#  place_design -directive ExtraPostPlacementOpt > $implDir/${topModuleName}_place_design.log
  place_design -directive EarlyBlockPlacement > $implDir/${topModuleName}_place_design.log

  phys_opt_design -directive AggressiveExplore > $implDir/${topModuleName}_PostPlace_opt_design.log
  write_checkpoint -force $implDir/${topModuleName}_place_design.dcp
#  route_design > $implDir/${topModuleName}_route_design.log
#  route_design -directive Explore -tns_cleanup > $implDir/${topModuleName}_route_design.log
  route_design -directive AggressiveExplore -tns_cleanup > $implDir/${topModuleName}_route_design.log
  phys_opt_design -directive AggressiveExplore > $implDir/${topModuleName}_PostRoute_opt_design.log
  write_checkpoint -force $implDir/${topModuleName}_route_design.dcp

  # Generate a timing report for convenience.
  report_timing_summary -warn_on_violation -file $implDir/report_timing_summary.rpt
  
  # Generate a utilization report
  report_utilization -hierarchical -file $implDir/report_utilization.rpt

  # Close the in-memory project.
  close_project
}



if { $runBitstreams } {

  # Create the output directory and remove previously generated files.
  if {[file isdir $bitDir]} {
    file delete -force $bitDir
  }
  file mkdir $bitDir

  puts "# HD INFO: Running bitstream"

  # Open the checkpoint for the initial configuration
  set route_dcp         $implDir/${topModuleName}_route_design.dcp
  if {![file isfile $route_dcp]} {
    exit
  }
  open_checkpoint $route_dcp
  read_xdc $srcDir/configuration.xdc

  # Generate Bitstream file.
  write_bitstream -force -bin_file -file $bitDir/${topModuleName} > $bitDir/${topModuleName}_write_bitstream.log

  # Generate Flash Files.
  write_cfgmem -force -format mcs -interface spix8 -size 128 -loadbit "up 0x0 $bitDir/${topModuleName}.bit" $bitDir/${topModuleName}.mcs
  write_cfgmem -force -format BIN -interface SPIx8 -size 128 -loadbit "up 0x0 $bitDir/${topModuleName}.bit" $bitDir/${topModuleName}.bin   
  # Close the in-memory project.
  close_project
}

puts "# HD INFO: Close project"
