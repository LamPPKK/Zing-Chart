#!/usr/bin/env ruby
# frozen_string_literal: true

require 'xcodeproj'

root = File.expand_path('../..', __dir__)
project_path = File.join(root, 'ios', 'Runner.xcodeproj')
project = Xcodeproj::Project.open(project_path)
runner = project.targets.find { |target| target.name == 'Runner' }
abort 'Runner target was not found.' unless runner

pubspec = File.read(File.join(root, 'pubspec.yaml'))
version_match = pubspec.match(/^version:\s*(\d+\.\d+\.\d+)\+(\d+)$/)
abort 'pubspec.yaml must declare version x.y.z+build.' unless version_match
marketing_version = version_match[1]
build_number = version_match[2]

def group(project, name)
  project.main_group.children.find { |child| child.respond_to?(:name) && child.name == name } ||
    project.main_group.new_group(name, name)
end

def file_reference(group, filename)
  group.files.find { |file| file.path == filename } || group.new_file(filename)
end

def add_source(target, reference)
  return if target.source_build_phase.files_references.include?(reference)

  target.source_build_phase.add_file_reference(reference, true)
end

def add_resource(target, reference)
  return if target.resources_build_phase.files_references.include?(reference)

  target.resources_build_phase.add_file_reference(reference, true)
end

def configure_target(target, values)
  target.build_configurations.each do |configuration|
    values.each { |key, value| configuration.build_settings[key] = value }
  end
end

def embed_product(runner, target, name, destination)
  phase = runner.copy_files_build_phases.find { |candidate| candidate.name == name } ||
    runner.new_copy_files_build_phase(name)
  phase.dst_subfolder_spec = destination
  unless phase.files_references.include?(target.product_reference)
    phase.add_file_reference(target.product_reference, true)
  end
  runner.add_dependency(target) unless runner.dependencies.any? { |item| item.target == target }
end

shared_group = group(project, 'SharedCompanion')
command_source = file_reference(shared_group, 'CompanionCommand.swift')
add_source(runner, command_source)
configure_target(runner, 'CODE_SIGN_ENTITLEMENTS' => 'Runner/Runner.entitlements')

widget_group = group(project, 'ZingChartWidget')
widget_source = file_reference(widget_group, 'ZingChartWidget.swift')
widget_target = project.targets.find { |target| target.name == 'ZingChartWidget' } ||
  project.new_target(:app_extension, 'ZingChartWidget', :ios, '17.0')
add_source(widget_target, command_source)
add_source(widget_target, widget_source)
configure_target(
  widget_target,
  'APPLICATION_EXTENSION_API_ONLY' => 'YES',
  'CODE_SIGN_ENTITLEMENTS' => 'ZingChartWidget/ZingChartWidget.entitlements',
  'CURRENT_PROJECT_VERSION' => build_number,
  'GENERATE_INFOPLIST_FILE' => 'NO',
  'INFOPLIST_FILE' => 'ZingChartWidget/Info.plist',
  'IPHONEOS_DEPLOYMENT_TARGET' => '17.0',
  'MARKETING_VERSION' => marketing_version,
  'PRODUCT_BUNDLE_IDENTIFIER' => 'software.baycho.zmp3chart.widget',
  'PRODUCT_NAME' => '$(TARGET_NAME)',
  'SKIP_INSTALL' => 'YES',
  'SWIFT_VERSION' => '5.0',
  'TARGETED_DEVICE_FAMILY' => '1,2'
)
embed_product(runner, widget_target, 'Embed App Extensions', '13')

watch_group = group(project, 'ZingChartWatch')
watch_sources = %w[ZingChartWatchApp.swift WatchSessionModel.swift WatchPlayerView.swift]
watch_target = project.targets.find { |target| target.name == 'ZingChartWatch' } ||
  project.new_target(:watch2_app, 'ZingChartWatch', :watchos, '10.0')
watch_sources.each { |source| add_source(watch_target, file_reference(watch_group, source)) }
watch_assets = file_reference(watch_group, 'Assets.xcassets')
add_resource(watch_target, watch_assets)
configure_target(
  watch_target,
  'ASSETCATALOG_COMPILER_APPICON_NAME' => 'AppIcon',
  'CURRENT_PROJECT_VERSION' => build_number,
  'GENERATE_INFOPLIST_FILE' => 'NO',
  'INFOPLIST_FILE' => 'ZingChartWatch/Info.plist',
  'MARKETING_VERSION' => marketing_version,
  'PRODUCT_BUNDLE_IDENTIFIER' => 'software.baycho.zmp3chart.watchkitapp',
  'PRODUCT_NAME' => '$(TARGET_NAME)',
  'SDKROOT' => 'watchos',
  'SKIP_INSTALL' => 'YES',
  'SWIFT_VERSION' => '5.0',
  'TARGETED_DEVICE_FAMILY' => '4',
  'WATCHOS_DEPLOYMENT_TARGET' => '10.0'
)
embed_product(runner, watch_target, 'Embed Watch Content', '16')

project.save
puts "Prepared WidgetKit and watchOS targets for #{marketing_version}+#{build_number}."
