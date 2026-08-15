#!/usr/bin/env ruby
# frozen_string_literal: true

require 'xcodeproj'

root = File.expand_path('../..', __dir__)
project = Xcodeproj::Project.open(File.join(root, 'macos', 'Runner.xcodeproj'))
runner = project.targets.find { |target| target.name == 'Runner' }
abort 'macOS Runner target was not found.' unless runner

pubspec = File.read(File.join(root, 'pubspec.yaml'))
version_match = pubspec.match(/^version:\s*(\d+\.\d+\.\d+)\+(\d+)$/)
abort 'pubspec.yaml must declare version x.y.z+build.' unless version_match

def group(project, name)
  project.main_group.children.find { |child| child.respond_to?(:name) && child.name == name } ||
    project.main_group.new_group(name, name)
end

def reference(group, filename)
  group.files.find { |file| file.path == filename } || group.new_file(filename)
end

def source(target, file)
  target.source_build_phase.add_file_reference(file, true) unless
    target.source_build_phase.files_references.include?(file)
end

shared = group(project, 'SharedCompanion')
command = reference(shared, 'CompanionCommand.swift')
source(runner, command)

widget_group = group(project, 'ZingChartWidget')
widget_source = reference(widget_group, 'ZingChartWidget.swift')
widget = project.targets.find { |target| target.name == 'ZingChartWidget' } ||
  project.new_target(:app_extension, 'ZingChartWidget', :osx, '14.0')
source(widget, command)
source(widget, widget_source)
widget.build_configurations.each do |configuration|
  configuration.build_settings.merge!(
    'APPLICATION_EXTENSION_API_ONLY' => 'YES',
    'CODE_SIGN_ENTITLEMENTS' => 'ZingChartWidget/ZingChartWidget.entitlements',
    'CURRENT_PROJECT_VERSION' => version_match[2],
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'INFOPLIST_FILE' => 'ZingChartWidget/Info.plist',
    'MACOSX_DEPLOYMENT_TARGET' => '14.0',
    'MARKETING_VERSION' => version_match[1],
    'PRODUCT_BUNDLE_IDENTIFIER' => 'software.baycho.zmp3chart.widget.macos',
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'SDKROOT' => 'macosx',
    'SKIP_INSTALL' => 'YES',
    'SWIFT_VERSION' => '5.0'
  )
end

phase = runner.copy_files_build_phases.find { |candidate| candidate.name == 'Embed App Extensions' } ||
  runner.new_copy_files_build_phase('Embed App Extensions')
phase.dst_subfolder_spec = '13'
phase.add_file_reference(widget.product_reference, true) unless
  phase.files_references.include?(widget.product_reference)
runner.add_dependency(widget) unless runner.dependencies.any? { |item| item.target == widget }

project.save
puts "Prepared macOS WidgetKit target for #{version_match[1]}+#{version_match[2]}."
