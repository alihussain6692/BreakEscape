#!/usr/bin/env ruby
# frozen_string_literal: true

# Break Escape Scenario Validator
# Validates scenario.json.erb files by rendering ERB to JSON and checking against schema
#
# Usage:
#   ruby scripts/validate_scenario.rb scenarios/ceo_exfil/scenario.json.erb
#   ruby scripts/validate_scenario.rb scenarios/ceo_exfil/scenario.json.erb --schema scripts/scenario-schema.json

require 'erb'
require 'json'
require 'optparse'
require 'pathname'
require 'set'
require 'base64'

# Try to load json-schema gem, provide helpful error if missing
begin
  require 'json-schema'
rescue LoadError
  $stderr.puts <<~ERROR
    ERROR: json-schema gem is required for validation.

    Install it with:
      gem install json-schema

    Or add to Gemfile:
      gem 'json-schema'

    Then run: bundle install
  ERROR
  exit 1
end

# ScenarioBinding class - replicates the one from app/models/break_escape/mission.rb
class ScenarioBinding
  def initialize(vm_context = {})
    require 'securerandom'
    @random_password = SecureRandom.alphanumeric(8)
    @random_pin = rand(1000..9999).to_s
    @random_code = SecureRandom.hex(4)
    @vm_context = vm_context || {}
  end

  attr_reader :random_password, :random_pin, :random_code, :vm_context

  # Get a VM from the context by title, or return a fallback VM object
  def vm_object(title, fallback = {})
    if vm_context && vm_context['hacktivity_mode'] && vm_context['vms']
      vm = vm_context['vms'].find { |v| v['title'] == title }
      return vm.to_json if vm
    end

    result = fallback.dup
    if vm_context && vm_context['vm_ips'] && vm_context['vm_ips'][title]
      result['ip'] = vm_context['vm_ips'][title]
    end
    result.to_json
  end

  # Get flags for a specific VM from the context
  def flags_for_vm(vm_name, fallback = [])
    if vm_context && vm_context['flags_by_vm']
      flags = vm_context['flags_by_vm'][vm_name]
      return flags.to_json if flags
    end
    fallback.to_json
  end

  # Get VM flags as a JSON array for use in the top-level 'flags' object.
  # Mirrors flags_for_vm but used in the top-level flags: { vm_name: vm_flags_json('vm_name') } pattern.
  def vm_flags_json(vm_name, fallback = [])
    flags_for_vm(vm_name, fallback)
  end

  def get_binding
    binding
  end
end

# Load valid item types from the objects asset directory.
# Returns a Set of type strings (filenames without .png extension), or nil if the directory
# cannot be found (in which case callers should skip the check).
def load_valid_item_types(base_dir)
  assets_dir = File.join(base_dir, 'public', 'break_escape', 'assets', 'objects')
  return nil unless Dir.exist?(assets_dir)

  types = Dir.glob(File.join(assets_dir, '*.png')).map do |f|
    File.basename(f, '.png')
  end
  Set.new(types)
end

# Render ERB template to JSON
def render_erb_to_json(erb_path, vm_context = {})
  unless File.exist?(erb_path)
    raise "ERB file not found: #{erb_path}"
  end

  erb_content = File.read(erb_path)
  erb = ERB.new(erb_content)
  binding_context = ScenarioBinding.new(vm_context)
  json_output = erb.result(binding_context.get_binding)

  JSON.parse(json_output)
rescue JSON::ParserError => e
  raise "Invalid JSON after ERB processing: #{e.message}\n\nGenerated JSON:\n#{json_output}"
rescue StandardError => e
  raise "Error processing ERB: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
end

# Validate JSON against schema
def validate_json(json_data, schema_path)
  unless File.exist?(schema_path)
    raise "Schema file not found: #{schema_path}"
  end

  schema = JSON.parse(File.read(schema_path))
  errors = JSON::Validator.fully_validate(schema, json_data, strict: false)

  errors
rescue JSON::ParserError => e
  raise "Invalid JSON schema: #{e.message}"
end

# Pre-validation: check critical structure issues before schema validation
# This prevents cryptic nil errors from deeply nested code
def check_structure_validity(json_data)
  issues = []

  # Validate rooms structure
  if json_data.key?('rooms')
    if json_data['rooms'].is_a?(Array)
      issues << "❌ INVALID: 'rooms' must be a JSON object {}, not an array []. Structure should be: \"rooms\": { \"room_id\": { ... }, \"another_room\": { ... } }"
    elsif !json_data['rooms'].is_a?(Hash)
      issues << "❌ INVALID: 'rooms' must be a JSON object {} (hash), got #{json_data['rooms'].class}"
    end
  end

  # Validate startItemsInInventory structure
  if json_data.key?('startItemsInInventory')
    if json_data['startItemsInInventory'].is_a?(Hash)
      issues << "❌ INVALID: 'startItemsInInventory' must be a JSON array [], not an object {}. Structure should be: \"startItemsInInventory\": [ { \"type\": \"phone\", \"name\": \"...\" }, ... ]"
    elsif !json_data['startItemsInInventory'].is_a?(Array)
      issues << "❌ INVALID: 'startItemsInInventory' must be a JSON array [], got #{json_data['startItemsInInventory'].class}"
    end
  end

  # Validate NPCs structure if present
  if json_data.key?('npcs')
    if !json_data['npcs'].is_a?(Array)
      issues << "❌ INVALID: 'npcs' must be a JSON array [], got #{json_data['npcs'].class}"
    end
  end

  # Validate objectives structure if present
  if json_data.key?('objectives')
    if !json_data['objectives'].is_a?(Array)
      issues << "❌ INVALID: 'objectives' must be a JSON array [], got #{json_data['objectives'].class}"
    end
  end

  issues
end

# Check that ink files exist and compile
def check_ink_files(json_data, base_dir)
  issues = []
  ink_files_to_check = Set.new

  # Collect all referenced ink files from NPCs
  json_data['rooms']&.each do |room_id, room|
    room['npcs']&.each_with_index do |npc, idx|
      if npc['storyPath']
        path = "rooms/#{room_id}/npcs[#{idx}]"
        ink_files_to_check.add({ path: path, storyPath: npc['storyPath'] })
      end
    end
  end

  # Check each ink file
  ink_files_to_check.each do |entry|
    story_path = entry[:storyPath]
    npc_path = entry[:path]

    # First, check if the .json compiled version exists
    json_path = story_path.sub(/\.ink$/, '.json')
    full_json_path = File.join(base_dir, json_path)

    unless File.exist?(full_json_path)
      # Check if the source .ink file exists
      source_ink_path = story_path.sub(/\.json$/, '.ink')
      full_ink_path = File.join(base_dir, source_ink_path)

      if File.exist?(full_ink_path)
        # Try to compile it using inklecate with -j for JSON output
        begin
          output = `inklecate -j "#{full_ink_path}" 2>&1`
          status = $?.exitstatus

          # Parse the output to check for compilation errors
          # inklecate outputs JSON status lines
          if output.include?('"compile-success": false') || output.include?('"ERROR:') || status != 0
            # Extract error message if present
            error_msg = output.lines.find { |line| line.include?('"issues"') }
            issues << "❌ INVALID: '#{npc_path}' references ink file '#{source_ink_path}' which fails to compile:\n#{error_msg || output}"
          end
        rescue => e
          issues << "❌ INVALID: '#{npc_path}' references ink file '#{source_ink_path}' but compilation check failed: #{e.message}"
        end
      else
        issues << "❌ INVALID: '#{npc_path}' references ink file '#{story_path}' which does not exist (checked for both .json and .ink versions)"
      end
    end
  end

  issues
end

# Check for common issues and structural problems
def check_common_issues(json_data, valid_item_types = nil)
  issues = []

  # Recursive helper: check item type and all nested contents/itemsHeld
  # A type is valid if an exact asset file exists, OR if any numbered/variant file starting with
  # that type name exists (e.g. type "safe" is valid when safe1.png, safe2.png etc. exist).
  check_item_type = lambda do |item, item_path|
    if valid_item_types && item['type']
      t = item['type']
      exact_match = valid_item_types.include?(t)
      variant_match = !exact_match && valid_item_types.any? { |v| v.start_with?(t) }
      unless exact_match || variant_match
        issues << "❌ INVALID: '#{item_path}' has type '#{t}' but no matching sprite found at assets/objects/#{t}.png (nor any #{t}*.png variant) — check the spelling or add the asset"
      end
    end
    item['contents']&.each_with_index { |c, i| check_item_type.call(c, "#{item_path}/contents[#{i}]") }
    item['itemsHeld']&.each_with_index { |c, i| check_item_type.call(c, "#{item_path}/itemsHeld[#{i}]") }
  end
  start_room_id = json_data['startRoom']

  # Valid directions for room connections
  valid_directions = %w[north south east west]

  # Track features for suggestions
  has_vm_launcher = false
  has_flag_station = false
  has_pc_with_files = false
  has_phone_npc_with_messages = false
  has_phone_npc_with_events = false
  has_opening_cutscene = false
  has_closing_debrief = false
  has_person_npcs = false
  has_npc_with_waypoints = false
  has_phone_contacts = false
  phone_npcs_without_messages = []
  lock_types_used = Set.new
  has_rfid_lock = false
  has_bluetooth_lock = false
  has_pin_lock = false
  has_password_lock = false
  has_key_lock = false
  has_security_tools = false
  has_container_with_contents = false
  has_readable_items = false
  has_music = json_data.key?('music')
  has_launch_device = false
  has_hostile_npcs = false
  has_global_var_on_ko = false
  has_skip_if_global = false
  has_collection_groups = false
  # For cross-reference checks
  collection_groups_used = Set.new  # collection_group values on items
  target_groups_used = Set.new      # targetGroup values on tasks
  all_npc_ids = Set.new             # all NPC IDs in rooms
  all_room_ids = Set.new            # all room IDs
  all_object_ids = Set.new          # all object IDs with explicit id field
  has_puzzle_graph_metadata = false # true if any object/item has puzzle_graph_unlocks
  puzzle_graph_unlock_targets = []  # [{target: str, path: str}] for post-loop cross-ref
  locked_room_ids = Set.new         # room IDs that are locked (for graph key-coverage analysis)
  locked_objects_info = []          # [{path:, name:, useful:}] locked containers for dead-end check
  vm_launcher_room_ids = Set.new    # room IDs containing a vm-launcher (any variant)
  lockpick_items = []               # [{path:, has_unlocks:}] lockpick items for graph annotation check
  key_locked_targets = []           # [{path:, name:}] all key-lockable things (lockType: 'key') for hint list

  # Collect global variables defined in scenario (needed for cross-reference checks)
  global_variables_defined = Set.new
  if json_data['globalVariables']
    global_variables_defined.merge(json_data['globalVariables'].keys)
  end

  # Collect all valid task IDs from objectives (for taskOnKO cross-reference)
  all_task_ids = Set.new
  json_data['objectives']&.each do |obj|
    obj['tasks']&.each { |t| all_task_ids.add(t['taskId']) if t['taskId'] }
  end

  # Collect targetGroup values from tasks (for collection_group cross-reference)
  json_data['objectives']&.each do |obj|
    obj['tasks']&.each do |t|
      target_groups_used.add(t['targetGroup']) if t['targetGroup']
    end
  end

  # Helper: recursively scan items (including contents) for collection_groups and object IDs
  scan_item_for_groups = lambda do |item|
    collection_groups_used.add(item['collection_group']) if item['collection_group']
    all_object_ids.add(item['id']) if item['id']
    item['contents']&.each { |c| scan_item_for_groups.call(c) }
    item['itemsHeld']&.each { |c| scan_item_for_groups.call(c) }
  end

  # Check rooms
  if json_data['rooms']
    json_data['rooms'].each do |room_id, room|
      all_room_ids.add(room_id)
      locked_room_ids.add(room_id) if room['locked']
      # Collect NPC IDs and object IDs for cross-reference
      room['npcs']&.each { |npc| all_npc_ids.add(npc['id']) if npc['id'] }
      room['objects']&.each { |obj| scan_item_for_groups.call(obj) }

      # Check for invalid room connection directions (diagonal directions)
      if room['connections']
        room['connections'].each do |direction, target|
          unless valid_directions.include?(direction)
            issues << "❌ INVALID: Room '#{room_id}' uses invalid direction '#{direction}' - only north, south, east, west are valid (not northeast, southeast, etc.)"
          end

          # Check reverse connections if target is a single room
          if target.is_a?(String) && json_data['rooms'][target]
            reverse_dir = case direction
            when 'north' then 'south'
            when 'south' then 'north'
            when 'east' then 'west'
            when 'west' then 'east'
            end
            target_room = json_data['rooms'][target]
            if target_room['connections']
              has_reverse = target_room['connections'].any? do |dir, targets|
                (dir == reverse_dir) && (targets == room_id || (targets.is_a?(Array) && targets.include?(room_id)))
              end
              unless has_reverse
                issues << "⚠️ WARNING: Room '#{room_id}' connects #{direction} to '#{target}', but '#{target}' doesn't connect #{reverse_dir} back - bidirectional connections recommended"
              end
            end
          end
        end
      end

      # Check room objects
      if room['objects']
        room['objects'].each_with_index do |obj, idx|
          path = "rooms/#{room_id}/objects[#{idx}]"

          # Check item type (and all nested contents/itemsHeld) against known asset files
          check_item_type.call(obj, path)

          # Check for incorrect VM launcher configuration (type: "pc" with vmAccess)
          if obj['type'] == 'pc' && obj['vmAccess']
            issues << "❌ INVALID: '#{path}' uses type: 'pc' with vmAccess - should use type: 'vm-launcher' instead. See scenarios/secgen_vm_lab/scenario.json.erb for example"
          end

          # Track VM launchers (including variants: vm-launcher-kali, vm-launcher-desktop)
          if obj['type']&.start_with?('vm-launcher')
            vm_launcher_room_ids.add(room_id)
          end
          if obj['type'] == 'vm-launcher'
            has_vm_launcher = true
            unless obj['vm']
              issues << "⚠️ WARNING: '#{path}' (vm-launcher) missing 'vm' object - use ERB helper vm_object()"
            end
            unless obj.key?('hacktivityMode')
              issues << "⚠️ WARNING: '#{path}' (vm-launcher) missing 'hacktivityMode' field"
            end
          end

          # Track launch-device items
          if obj['type'] == 'launch-device'
            has_launch_device = true
            missing_launch_fields = []
            missing_launch_fields << 'mode' unless obj['mode']
            missing_launch_fields << 'acceptsVms' unless obj['acceptsVms'] && !obj['acceptsVms'].empty?
            missing_launch_fields << 'flags' unless obj['flags'] && !obj['flags'].empty?
            missing_launch_fields << 'onAbort' unless obj['onAbort']
            missing_launch_fields << 'onLaunch' unless obj['onLaunch']
            missing_launch_fields << 'abortConfirmText' unless obj['abortConfirmText']
            missing_launch_fields << 'launchConfirmText' unless obj['launchConfirmText']
            if missing_launch_fields.any?
              issues << "⚠️ WARNING: '#{path}' (launch-device) missing fields: #{missing_launch_fields.join(', ')} — launch-device items require mode, acceptsVms, flags, onAbort/onLaunch handlers, and confirm text for player dialogs. See scenarios/m01_first_contact/scenario.json.erb for reference"
            end
          end

          # Track flag stations
          if obj['type'] == 'flag-station'
            has_flag_station = true
            unless obj['acceptsVms'] && !obj['acceptsVms'].empty?
              issues << "⚠️ WARNING: '#{path}' (flag-station) missing or empty 'acceptsVms' array"
            end
            unless obj['flags']
              issues << "⚠️ WARNING: '#{path}' (flag-station) missing 'flags' array - use ERB helper flags_for_vm()"
            end
          end

          # Check for PC containers with files
          if obj['type'] == 'pc' && obj['contents'] && obj['contents'].any? { |item| item['type'] == 'text_file' || item['readable'] }
            has_pc_with_files = true
          end

          # Track containers with contents (safes, suitcases, bins, PCs, briefcases, etc.)
          container_types_with_contents = %w[safe suitcase bin bin1 pc briefcase bag]
          if container_types_with_contents.include?(obj['type']) && obj['contents'] && !obj['contents'].empty?
            has_container_with_contents = true
          end

          # REQUIRED: Containers with contents must specify locked field explicitly
          container_types = ['briefcase', 'bag', 'bag1', 'suitcase', 'safe', 'pc', 'bin1']
          if container_types.include?(obj['type']) && obj['contents'] && !obj['contents'].empty?
            unless obj.key?('locked')
              issues << "❌ INVALID: '#{path}' is a container with contents but missing required 'locked' field - must be explicitly true or false for server-side validation"
            end

            # Track dead-end locks: locked containers where no content is useful to the player
            if obj['locked']
              clue_types = %w[notes notes2 notes3 notes4 notes5 text_file key lockpick
                              fingerprint_kit rfid_cloner pin-cracker bluetooth_scanner phone]
              useful = obj['contents'].any? { |c| c['takeable'] || c['readable'] || clue_types.include?(c['type']) }
              locked_objects_info << { path: path, name: (obj['name'] || obj['type']), useful: useful }
            end
          end

          # Track readable items (notes, documents)
          if obj['readable'] || (obj['type'] == 'notes' && obj['text'])
            has_readable_items = true
          end

          # Track security tools
          if ['lockpick', 'fingerprint_kit', 'pin-cracker', 'bluetooth_scanner', 'rfid_cloner'].include?(obj['type'])
            has_security_tools = true
          end

          # Track lockpick items for graph annotation check
          if obj['type'] == 'lockpick'
            lockpick_items << { path: path, has_unlocks: !obj['puzzle_graph_unlocks'].nil? }
          end

          # Track lock types
          if obj['locked'] && obj['lockType']
            lock_types_used.add(obj['lockType'])
            case obj['lockType']
            when 'rfid'
              has_rfid_lock = true
            when 'bluetooth'
              has_bluetooth_lock = true
            when 'pin'
              has_pin_lock = true
            when 'password'
              has_password_lock = true
            when 'key'
              has_key_lock = true
              key_locked_targets << { path: path, name: (obj['name'] || obj['type']) }
              # Check for key locks without keyPins (REQUIRED, not recommended)
              unless obj['keyPins']
                issues << "❌ INVALID: '#{path}' has lockType: 'key' but missing required 'keyPins' array - key locks must specify keyPins array for lockpicking minigame"
              end
            end
          end

          # Check for key items without keyPins (REQUIRED, not recommended)
          if obj['type'] == 'key' && !obj['keyPins']
            issues << "❌ INVALID: '#{path}' (key item) missing required 'keyPins' array - key items must specify keyPins array for lockpicking"
          end

          # Cross-reference onRead.setVariable against globalVariables
          if obj['onRead']&.dig('setVariable')
            obj['onRead']['setVariable'].each_key do |var_name|
              unless global_variables_defined.include?(var_name)
                issues << "❌ INVALID: '#{path}/onRead/setVariable' references variable '#{var_name}' not defined in scenario.globalVariables. Add '#{var_name}': false to globalVariables."
              end
            end
          end

          # Cross-reference onPickup.setVariable against globalVariables
          if obj['onPickup']&.dig('setVariable')
            obj['onPickup']['setVariable'].each_key do |var_name|
              unless global_variables_defined.include?(var_name)
                issues << "❌ INVALID: '#{path}/onPickup/setVariable' references variable '#{var_name}' not defined in scenario.globalVariables. Add '#{var_name}': false to globalVariables."
              end
            end
          end

          # Check for items with id field (should use type field for #give_item tags)
          if obj['itemsHeld']
            obj['itemsHeld'].each_with_index do |item, item_idx|
              if item['id']
                issues << "❌ INVALID: '#{path}/itemsHeld[#{item_idx}]' has 'id' field - items should NOT have 'id' field. Use 'type' field to match #give_item tag parameter"
              end
            end
          end

          # puzzle_graph_* metadata tracking and suggestions (dungeon graph)
          if obj['puzzle_graph_unlocks']
            has_puzzle_graph_metadata = true
            Array(obj['puzzle_graph_unlocks']).each do |target|
              puzzle_graph_unlock_targets << { target: target, path: path, optional: (obj['puzzle_graph_optional'] == true) }
            end
          end

          # Suggest puzzle_graph_unlocks on clue items inside locked containers
          # Only fire when the container itself is already in the graph (has puzzle_graph_unlocks)
          if obj['locked'] && obj['puzzle_graph_unlocks'] && obj['contents']&.any?
            clue_types = %w[notes text_file phone]
            clue_contents = obj['contents'].select { |c| c['readable'] || clue_types.include?(c['type']) }
            clue_contents.each_with_index do |c, ci|
              c_path = "#{path}/contents[#{ci}] (#{c['type'] || c['name']})"
              if c['puzzle_graph_unlocks']
                has_puzzle_graph_metadata = true
                Array(c['puzzle_graph_unlocks']).each do |target|
                  puzzle_graph_unlock_targets << { target: target, path: c_path, optional: (c['puzzle_graph_optional'] == true) }
                end
              else
                issues << "💡 SUGGESTION: '#{c_path}' is a clue item inside locked container '#{obj['name'] || obj['type']}' but has no 'puzzle_graph_unlocks'. Add puzzle_graph_unlocks: '<lock_or_room_id>' to connect this clue to the dungeon graph (scripts/generate_dungeon_graph.rb)"
              end
            end
          end
        end
      end

      # Track room lock types
      if room['locked'] && room['lockType']
        lock_types_used.add(room['lockType'])
        case room['lockType']
        when 'rfid'
          has_rfid_lock = true
        when 'bluetooth'
          has_bluetooth_lock = true
        when 'pin'
          has_pin_lock = true
        when 'password'
          has_password_lock = true
        when 'key'
          has_key_lock = true
          key_locked_targets << { path: "rooms/#{room_id}", name: (room['name'] || room_id) }
          # Check for key locks without keyPins (REQUIRED, not recommended)
          unless room['keyPins']
            issues << "❌ INVALID: 'rooms/#{room_id}' has lockType: 'key' but missing required 'keyPins' array - key locks must specify keyPins array for lockpicking minigame"
          end
        end
      end

      # Check NPCs in rooms
      if room['npcs']
        room['npcs'].each_with_index do |npc, idx|
          path = "rooms/#{room_id}/npcs[#{idx}]"

          # Track person NPCs
          if npc['npcType'] == 'person' || (!npc['npcType'] && npc['position'])
            has_person_npcs = true

            # Check for waypoints in behavior.patrol
            if npc['behavior'] && npc['behavior']['patrol']
              patrol = npc['behavior']['patrol']
              # Check for single-room waypoints
              if patrol['waypoints'] && !patrol['waypoints'].empty?
                has_npc_with_waypoints = true
              end
              # Check for multi-room route waypoints
              if patrol['route'] && patrol['route'].is_a?(Array) && patrol['route'].any? { |segment| segment['waypoints'] && !segment['waypoints'].empty? }
                has_npc_with_waypoints = true
              end
            end
          end

          # Track hostile NPCs (hostile can be true or a config object)
          if npc['behavior']&.key?('hostile') && npc['behavior']['hostile']
            has_hostile_npcs = true
          end

          # Track and cross-reference globalVarOnKO
          if npc['globalVarOnKO']
            has_global_var_on_ko = true
            var_name = npc['globalVarOnKO']
            unless global_variables_defined.include?(var_name)
              issues << "❌ INVALID: '#{path}' globalVarOnKO references '#{var_name}' which is not defined in scenario.globalVariables. Add '#{var_name}': false to globalVariables."
            end
          end

          # Track and cross-reference taskOnKO
          if npc['taskOnKO']
            task_id = npc['taskOnKO']
            unless all_task_ids.include?(task_id)
              issues << "❌ INVALID: '#{path}' taskOnKO references task '#{task_id}' which does not exist in any objective's tasks. Ensure the taskId is correct."
            end
          end

          # Track timedConversation.skipIfGlobal
          if npc['timedConversation']&.dig('skipIfGlobal')
            has_skip_if_global = true
          end

          # Check for opening cutscene in starting room
          if room_id == start_room_id && npc['timedConversation']
            has_opening_cutscene = true
            if npc['timedConversation']['delay'] != 0
              issues << "⚠️ WARNING: '#{path}' timedConversation delay is #{npc['timedConversation']['delay']} - opening cutscenes typically use delay: 0"
            end
          end

          # Validate timedConversation structure
          if npc['timedConversation']
            tc = npc['timedConversation']
            # Check for incorrect property name
            if tc['knot'] && !tc['targetKnot']
              issues << "❌ INVALID: '#{path}' timedConversation uses 'knot' property - should use 'targetKnot' instead. Change 'knot' to 'targetKnot'"
            end
            # Check for missing targetKnot
            unless tc['targetKnot']
              issues << "❌ INVALID: '#{path}' timedConversation missing required 'targetKnot' property - must specify the Ink knot to navigate to"
            end
            # Check for missing delay
            unless tc.key?('delay')
              issues << "⚠️ WARNING: '#{path}' timedConversation missing 'delay' property - should specify delay in milliseconds (0 for immediate)"
            end
          end

          # Validate eventMapping vs eventMappings (parameter name mismatch)
          if npc['eventMapping'] && !npc['eventMappings']
            issues << "❌ INVALID: '#{path}' uses 'eventMapping' (singular) - should use 'eventMappings' (plural). The NPCManager expects 'eventMappings' and won't register event listeners with 'eventMapping'"
          end

          # Validate eventMappings structure
          if npc['eventMappings']
            # Check if it's an array
            unless npc['eventMappings'].is_a?(Array)
              issues << "❌ INVALID: '#{path}' eventMappings is not an array - must be an array of event mapping objects"
            else
              npc['eventMappings'].each_with_index do |mapping, idx|
                mapping_path = "#{path}/eventMappings[#{idx}]"

                # Check for incorrect property name (knot vs targetKnot)
                if mapping['knot'] && !mapping['targetKnot']
                  issues << "❌ INVALID: '#{mapping_path}' uses 'knot' property - should use 'targetKnot' instead. Change 'knot' to 'targetKnot'"
                end

                # Check for missing eventPattern
                unless mapping['eventPattern']
                  issues << "❌ INVALID: '#{mapping_path}' missing required 'eventPattern' property - must specify the event pattern to listen for (e.g., 'global_variable_changed:varName')"
                end

                # For person NPCs only: check for missing conversationMode when targetKnot is present
                # (phone NPCs have a different pattern — see phone NPC checks below)
                if npc['npcType'] != 'phone' && mapping['targetKnot'] && !mapping['conversationMode']
                  issues << "⚠️ WARNING: '#{mapping_path}' has targetKnot but no conversationMode - should specify 'person-chat' to indicate this is a cutscene trigger"
                end

                # Check for missing background when conversationMode is person-chat
                if mapping['conversationMode'] == 'person-chat' && !mapping['background']
                  issues << "⚠️ WARNING: '#{mapping_path}' has conversationMode: 'person-chat' but no background - person-chat cutscenes typically need a background image (e.g., 'assets/backgrounds/hq1.png')"
                end

                # Phone NPC event mapping anti-patterns
                if npc['npcType'] == 'phone'
                  # targetKnot does NOT work for phone NPCs after the first conversation.
                  # After the first open, storyState is restored and currentKnot is bypassed entirely.
                  if mapping['targetKnot']
                    issues << "❌ INVALID: '#{mapping_path}' is a phone NPC event mapping with 'targetKnot' — this does NOT work after the first conversation. Once a storyState is saved, targetKnot is ignored on reopen. Correct pattern: use 'setGlobal' to set a flag, then add a conditional hub option in the Ink story: '+ {flag_var} [Ask about it] -> knot'. Also add 'sendTimedMessage' to notify the player that new content is available."
                  end

                  # conversationMode is silently ignored for phone NPCs
                  if mapping['conversationMode']
                    issues << "❌ INVALID: '#{mapping_path}' is a phone NPC event mapping with 'conversationMode: \"#{mapping['conversationMode']}\"' — this field is not used for phone NPCs and has no effect. Remove it."
                  end

                  # targetKnot inside sendTimedMessage is not used either
                  if mapping['sendTimedMessage']&.key?('targetKnot')
                    issues << "❌ INVALID: '#{mapping_path}/sendTimedMessage' has a 'targetKnot' field — targetKnot inside sendTimedMessage is not used for phone NPCs and will be silently ignored. Remove it. To surface a new dialogue option, use 'setGlobal' on the event mapping and add a conditional hub choice in the Ink story."
                  end

                  # Event mappings that produce no visible effect are likely broken/incomplete
                  has_effect = mapping['setGlobal'] || mapping['sendTimedMessage'] ||
                               mapping['completeTask'] || mapping['unlockTask'] || mapping['unlockAim']
                  unless has_effect
                    issues << "⚠️ WARNING: '#{mapping_path}' is a phone NPC event mapping with no visible effect (no setGlobal, sendTimedMessage, completeTask, unlockTask, or unlockAim). Use 'sendTimedMessage' to notify the player, and 'setGlobal' to flag that a new hub option is available. Example: { \"eventPattern\": \"...\", \"onceOnly\": true, \"setGlobal\": { \"flag_var\": true }, \"sendTimedMessage\": { \"delay\": 1000, \"message\": \"...\" } }"
                  end
                end
              end
            end
          end

          # Track phone NPCs (phone contacts)
          if npc['npcType'] == 'phone'
            has_phone_contacts = true

            # Validate phone NPC structure - should have phoneId
            unless npc['phoneId']
              issues << "❌ INVALID: '#{path}' (phone NPC) missing required 'phoneId' field - phone NPCs must specify which phone they appear on (e.g., 'player_phone')"
            end

            # Validate phone NPC structure - should have storyPath
            unless npc['storyPath']
              issues << "❌ INVALID: '#{path}' (phone NPC) missing required 'storyPath' field - phone NPCs must have a path to their Ink story JSON file"
            end

            # Validate phone NPC structure - should NOT have position (phone NPCs don't have positions)
            if npc['position']
              issues << "⚠️ WARNING: '#{path}' (phone NPC) has 'position' field - phone NPCs should NOT have position (they're not in-world sprites). Remove the position field."
            end

            # Validate phone NPC structure - should NOT have spriteSheet (phone NPCs don't have sprites)
            if npc['spriteSheet']
              issues << "⚠️ WARNING: '#{path}' (phone NPC) has 'spriteSheet' field - phone NPCs should NOT have spriteSheet (they're not in-world sprites). Remove the spriteSheet field."
            end

            # Validate timedMessages structure for phone NPCs
            if npc['timedMessages']
              unless npc['timedMessages'].is_a?(Array)
                issues << "❌ INVALID: '#{path}' timedMessages is not an array - must be an array of timed message objects"
              else
                npc['timedMessages'].each_with_index do |msg, idx|
                  msg_path = "#{path}/timedMessages[#{idx}]"

                  # Check for missing message field
                  unless msg['message']
                    issues << "❌ INVALID: '#{msg_path}' missing required 'message' field - must specify the text content of the message"
                  end

                  # Check for incorrect property name (text vs message)
                  if msg['text'] && !msg['message']
                    issues << "❌ INVALID: '#{msg_path}' uses 'text' property - should use 'message' instead. The NPCManager reads msg.message, not msg.text"
                  end

                  # Check for missing delay field
                  unless msg.key?('delay')
                    issues << "⚠️ WARNING: '#{msg_path}' missing 'delay' property - should specify delay in milliseconds (0 for immediate)"
                  end

                  # Check for incorrect property name (knot vs targetKnot) in timed messages
                  if msg['knot'] && !msg['targetKnot']
                    issues << "❌ INVALID: '#{msg_path}' uses 'knot' property - should use 'targetKnot' instead. Change 'knot' to 'targetKnot'"
                  end
                end
              end
            end

            # Track phone NPCs with messages in rooms
            if npc['timedMessages'] && !npc['timedMessages'].empty?
              has_phone_npc_with_messages = true
            else
              # Track phone NPCs without timed messages
              phone_npcs_without_messages << "#{path} (#{npc['displayName'] || npc['id']})"
            end

            # Track phone NPCs with event mappings in rooms
            if npc['eventMappings'] && !npc['eventMappings'].empty?
              has_phone_npc_with_events = true
            end
          end

          # Check for items with id field in NPC itemsHeld
          if npc['itemsHeld']
            npc['itemsHeld'].each_with_index do |item, item_idx|
              if item['id']
                issues << "❌ INVALID: '#{path}/itemsHeld[#{item_idx}]' has 'id' field - items should NOT have 'id' field. Use 'type' field to match #give_item tag parameter (e.g., type: 'id_badge' matches #give_item:id_badge)"
              end

              # Check item type against known asset files
              check_item_type.call(item, "#{path}/itemsHeld[#{item_idx}]")

              # Track security tools in NPC itemsHeld
              if ['lockpick', 'fingerprint_kit', 'pin-cracker', 'bluetooth_scanner', 'rfid_cloner'].include?(item['type'])
                has_security_tools = true
              end

              # Track lockpick items in NPC itemsHeld for graph annotation check
              if item['type'] == 'lockpick'
                lockpick_items << { path: "#{path}/itemsHeld[#{item_idx}]", has_unlocks: !item['puzzle_graph_unlocks'].nil? }
              end

              # Track launch-device in NPC itemsHeld
              has_launch_device = true if item['type'] == 'launch-device'

              # Track puzzle_graph_unlocks on NPC-held items (e.g., Sarah's key chain)
              if item['puzzle_graph_unlocks']
                has_puzzle_graph_metadata = true
                Array(item['puzzle_graph_unlocks']).each do |target|
                  puzzle_graph_unlock_targets << { target: target, path: "#{path}/itemsHeld[#{item_idx}]", optional: (item['puzzle_graph_optional'] == true) }
                end
              end
            end
          end
        end
      end
    end
  end

  # Check startItemsInInventory for security tools and readable items
  if json_data['startItemsInInventory']
    json_data['startItemsInInventory'].each_with_index do |item, idx|
      check_item_type.call(item, "startItemsInInventory[#{idx}]")
      # Track security tools
      if ['lockpick', 'fingerprint_kit', 'pin-cracker', 'bluetooth_scanner', 'rfid_cloner'].include?(item['type'])
        has_security_tools = true
      end

      # Track lockpick items in startItemsInInventory for graph annotation check
      if item['type'] == 'lockpick'
        lockpick_items << { path: "startItemsInInventory[#{idx}]", has_unlocks: !item['puzzle_graph_unlocks'].nil? }
      end

      # Track readable items
      if item['readable'] || (item['type'] == 'notes' && item['text'])
        has_readable_items = true
      end
    end
  end

  # Check phoneNPCs section - this is the OLD/INCORRECT format
  if json_data['phoneNPCs']
    json_data['phoneNPCs'].each_with_index do |npc, idx|
      path = "phoneNPCs[#{idx}]"

      # Flag incorrect structure - phone NPCs should be in rooms, not phoneNPCs section
      issues << "❌ INVALID: '#{path}' - Phone NPCs should be defined in 'rooms/{room_id}/npcs[]' arrays, NOT in a separate 'phoneNPCs' section. See scenarios/npc-sprite-test3/scenario.json.erb for correct format. Phone NPCs should be in the starting room (or room where phone is accessible) with npcType: 'phone'"

      # Track phone NPCs (phone contacts) - but note they're in wrong location
      has_phone_contacts = true

      # Track phone NPCs with messages
      if npc['timedMessages'] && !npc['timedMessages'].empty?
        has_phone_npc_with_messages = true
      else
        # Track phone NPCs without timed messages
        phone_npcs_without_messages << "#{path} (#{npc['displayName'] || npc['id']})"
      end

      # Track phone NPCs with event mappings (for closing debriefs)
      if npc['eventMappings'] && !npc['eventMappings'].any? { |m| m['eventPattern']&.include?('global_variable_changed') }
        has_phone_npc_with_events = true
      end

      # Check for closing debrief trigger
      if npc['eventMappings']
        npc['eventMappings'].each do |mapping|
          if mapping['eventPattern']&.include?('global_variable_changed')
            has_closing_debrief = true
          end
        end
      end
    end
  end

  # Check for event-driven cutscene architecture patterns
  person_npcs_with_event_cutscenes = []
  global_variables_referenced = Set.new
  # global_variables_defined already populated above

  # Check all NPCs for event-driven cutscene patterns
  json_data['rooms']&.each do |room_id, room|
    room['npcs']&.each_with_index do |npc, idx|
      path = "rooms/#{room_id}/npcs[#{idx}]"

      # Check for person NPCs with eventMappings (cutscene NPCs)
      if npc['npcType'] == 'person' && npc['eventMappings']
        npc['eventMappings'].each_with_index do |mapping, mapping_idx|
          mapping_path = "#{path}/eventMappings[#{mapping_idx}]"

          # Check if this is a cutscene trigger (has conversationMode)
          if mapping['conversationMode'] == 'person-chat'
            person_npcs_with_event_cutscenes << {
              npc_id: npc['id'],
              path: path,
              mapping: mapping
            }

            # Extract global variable name from event pattern
            if mapping['eventPattern']&.match(/global_variable_changed:(\w+)/)
              var_name = $1
              global_variables_referenced << var_name

              # Check if the global variable is defined
              unless global_variables_defined.include?(var_name)
                issues << "❌ INVALID: '#{mapping_path}' references global variable '#{var_name}' in eventPattern, but it's not defined in scenario.globalVariables. Add '#{var_name}' with an initial value (typically false) to globalVariables"
              end
            end

            # Check for missing spriteTalk when using non-numeric frame sprites
            if !npc['spriteTalk'] && npc['spriteSheet']
              # Sprites with named frames (not numeric indices) need spriteTalk
              named_frame_sprites = ['female_spy', 'male_spy', 'female_hacker_hood', 'male_doctor']
              if named_frame_sprites.include?(npc['spriteSheet'])
                issues << "⚠️ WARNING: '#{path}' uses spriteSheet '#{npc['spriteSheet']}' which has named frames, but no 'spriteTalk' property. Person-chat cutscenes will show frame errors. Add 'spriteTalk' property pointing to a headshot image (e.g., 'assets/characters/#{npc['spriteSheet']}_headshot.png')"
              end
            end

            # Validate background for person-chat cutscenes
            unless mapping['background']
              issues << "⚠️ WARNING: '#{mapping_path}' is a person-chat cutscene but has no 'background' property. Person-chat cutscenes should have a background image for better visual presentation (e.g., 'assets/backgrounds/hq1.png')"
            end

            # Check for onceOnly to prevent repeated cutscenes
            unless mapping['onceOnly']
              issues << "⚠️ WARNING: '#{mapping_path}' is a person-chat cutscene without 'onceOnly: true'. Cutscenes typically should only trigger once. Add 'onceOnly: true' unless you want the cutscene to repeat"
            end
          end
        end
      end

      # Check for phone NPCs setting global variables in their stories
      if npc['npcType'] == 'phone' && npc['storyPath']
        if npc['eventMappings']
          # Only flag if an eventMapping's sendTimedMessage looks like a cutscene trigger
          # (has targetKnot or conversationMode), not standard hint messages
          cutscene_event_mappings = npc['eventMappings'].select do |m|
            m['sendTimedMessage']&.key?('targetKnot') || m['sendTimedMessage']&.key?('conversationMode')
          end
          if cutscene_event_mappings.any?
            issues << "💡 BEST PRACTICE: '#{path}' appears to be a mission-ending phone NPC with sendTimedMessage. Consider using event-driven cutscene architecture instead: 1) Add #set_global:variable_name:true tag in Ink story, 2) Add #exit_conversation tag to close phone, 3) Create separate person NPC with eventMapping listening for global_variable_changed:variable_name. See scenarios/m01_first_contact/scenario.json.erb for reference implementation"
          end
        end
      end
    end
  end

  # Detect closing debrief: a person NPC with a person-chat eventMapping that is NOT the
  # opening cutscene (i.e. uses eventPattern, not timedConversation). m01 pattern: person NPC
  # with behavior.initiallyHidden: true listening for a global_variable_changed event.
  if person_npcs_with_event_cutscenes.any?
    has_closing_debrief = true
  end

  # Also detect closing debrief from room NPCs with global_variable_changed eventPatterns
  # (catches the pattern even if conversationMode is absent)
  unless has_closing_debrief
    json_data['rooms']&.each do |room_id, room|
      room['npcs']&.each do |npc|
        next unless npc['npcType'] == 'person' && npc['eventMappings']
        next unless npc['behavior']&.dig('initiallyHidden')
        if npc['eventMappings'].any? { |m| m['eventPattern']&.include?('global_variable_changed') }
          has_closing_debrief = true
          break
        end
      end
      break if has_closing_debrief
    end
  end

  # Check for orphaned global variable references
  orphaned_vars = global_variables_referenced - global_variables_defined
  orphaned_vars.each do |var_name|
    issues << "❌ INVALID: Global variable '#{var_name}' is referenced in eventPatterns but not defined in scenario.globalVariables. Add '#{var_name}' to globalVariables with an initial value (typically false for cutscene triggers)"
  end

  # Cross-reference task targetGroup against item collection_groups
  target_groups_used.each do |group|
    unless collection_groups_used.include?(group)
      issues << "❌ INVALID: Task uses targetGroup '#{group}' but no items have collection_group: '#{group}'. Add collection_group: '#{group}' to the relevant items."
    end
  end
  orphaned_groups = collection_groups_used - target_groups_used
  orphaned_groups.each do |group|
    issues << "⚠️ WARNING: Items use collection_group '#{group}' but no task has targetGroup: '#{group}'. Add a task with targetGroup: '#{group}' to track collection progress."
  end

  # Cross-reference task targetNPC, targetRoom, targetObject
  json_data['objectives']&.each_with_index do |obj, oi|
    obj['tasks']&.each_with_index do |task, ti|
      task_path = "objectives[#{oi}]/tasks[#{ti}] (#{task['taskId']})"
      if task['targetNPC'] && !all_npc_ids.include?(task['targetNPC'])
        issues << "❌ INVALID: #{task_path} references targetNPC '#{task['targetNPC']}' which does not exist in any room. Check the NPC id."
      end
      if task['targetRoom'] && !all_room_ids.include?(task['targetRoom'])
        issues << "❌ INVALID: #{task_path} references targetRoom '#{task['targetRoom']}' which is not a defined room."
      end
      if task['targetObject'] && !all_object_ids.include?(task['targetObject'])
        issues << "⚠️ WARNING: #{task_path} references targetObject '#{task['targetObject']}' but no object with that id was found. Ensure the object has an explicit 'id' field matching '#{task['targetObject']}'."
      end

      # Suggest puzzle_graph_unlocks on submit_flags tasks that gate further progress
      if task['type'] == 'submit_flags' && !task['puzzle_graph_unlocks'] && task['onComplete']
        issues << "💡 SUGGESTION: #{task_path} (submit_flags) has no 'puzzle_graph_unlocks'. Add puzzle_graph_unlocks: '<flag_node_id>' to connect flag submission to the dungeon graph (scripts/generate_dungeon_graph.rb)"
      elsif task['puzzle_graph_unlocks']
        has_puzzle_graph_metadata = true
      end
    end
  end

  # Check music section
  if json_data['music']
    music_events = json_data['music']['events'] || []
    music_events.each_with_index do |event, idx|
      music_path = "music/events[#{idx}]"
      next unless event['trigger']
      if (m = event['trigger'].match(/^conversation_closed:(.+)$/))
        npc_id = m[1]
        unless all_npc_ids.include?(npc_id)
          issues << "⚠️ WARNING: '#{music_path}' trigger references NPC '#{npc_id}' via conversation_closed but that NPC id was not found in any room."
        end
      elsif (m = event['trigger'].match(/^global_variable_changed:(.+)$/))
        var_name = m[1]
        unless global_variables_defined.include?(var_name)
          issues << "⚠️ WARNING: '#{music_path}' trigger references global variable '#{var_name}' via global_variable_changed but it is not defined in scenario.globalVariables."
        end
      end
    end
  end

  # Cross-reference puzzle_graph_unlocks targets against known room/object IDs
  puzzle_graph_unlock_targets.each do |entry|
    target = entry[:target]
    entry_path = entry[:path]
    # Only warn for targets that don't look like lock IDs and aren't known rooms/objects
    unless target.start_with?('lock_') || all_room_ids.include?(target) || all_object_ids.include?(target)
      issues << "⚠️ WARNING: '#{entry_path}' has puzzle_graph_unlocks: '#{target}' which is not a known room ID or object ID and doesn't look like a lock ID (lock_*). Verify this target is correct."
    end
  end

  # Graph structural analysis (when puzzle_graph metadata exists)
  if has_puzzle_graph_metadata && puzzle_graph_unlock_targets.any?
    # Count inbound edges per target — exclude optional paths
    target_counts = Hash.new(0)
    puzzle_graph_unlock_targets.each { |e| target_counts[e[:target]] += 1 unless e[:optional] }

    # Multiple solutions: more than one mandatory item unlocks the same target
    target_counts.each do |target, count|
      next if count < 2
      sources = puzzle_graph_unlock_targets.select { |e| e[:target] == target && !e[:optional] }.map { |e| e[:path] }
      issues << "⚠️ WARNING: #{count} items all point to the same unlock target '#{target}' — multiple solution paths exist. Sources: [#{sources.join(', ')}]. If one path is intentionally optional, add puzzle_graph_optional: true to that item. Otherwise this may allow players to bypass a challenge."
    end

    # Locked rooms with no inbound graph edge: the key for this door isn't mapped
    graph_targets = Set.new(puzzle_graph_unlock_targets.map { |e| e[:target] })
    locked_room_ids.each do |room_id|
      # Locked rooms can be targeted as room_id (door node) in puzzle_graph_unlocks
      unless graph_targets.include?(room_id)
        issues << "⚠️ WARNING: Room '#{room_id}' is locked but nothing has puzzle_graph_unlocks: '#{room_id}' — the key or clue for this door is not mapped in the dungeon graph. Add puzzle_graph_unlocks: '#{room_id}' to the item that provides access (key, PIN note, keycard, etc.)."
      end
    end
  end

  # Dead-end locks: locked containers where no content is useful
  locked_objects_info.each do |info|
    next if info[:useful]
    issues << "⚠️ WARNING: '#{info[:path]}' is locked ('#{info[:name]}') but contains no takeable items, readable notes, or clue objects — players have no reward for solving this lock. Add useful contents or remove the lock (set locked: false)."
  end

  # Lockpick items without puzzle_graph_unlocks
  unannotated_lockpicks = lockpick_items.reject { |lp| lp[:has_unlocks] }
  if unannotated_lockpicks.any?
    hint_list = key_locked_targets.map { |t| "'#{t[:path]}' (#{t[:name]})" }.join(', ')
    hint_list = hint_list.empty? ? 'none found' : hint_list
    unannotated_lockpicks.each do |lp|
      issues << "⚠️ WARNING: '#{lp[:path]}' is a lockpick but has no 'puzzle_graph_unlocks' — the dungeon graph won't show what it opens. Add puzzle_graph_unlocks: '<target>' (or an array). Key-locked targets in this scenario: #{hint_list}"
    end
  end

  # Check for submit_flags bypass: aims where VM flag tasks can be skipped
  json_data['objectives']&.each_with_index do |aim, oi|
    next unless aim['tasks']
    flag_tasks = aim['tasks'].select { |t| t['type'] == 'submit_flags' }
    next if flag_tasks.empty?
    # Non-flag tasks in the same aim that advance the scenario via onComplete
    bypass_tasks = aim['tasks'].reject { |t| t['type'] == 'submit_flags' }.select do |t|
      t.dig('onComplete', 'unlockAim') || t.dig('onComplete', 'unlockTask') || t.dig('onComplete', 'completeTask')
    end
    if bypass_tasks.any?
      task_ids = bypass_tasks.map { |t| t['taskId'] }.join(', ')
      aim_path = "objectives[#{oi}] (#{aim['aimId']})"
      issues << "⚠️ WARNING: #{aim_path} contains submit_flags task(s) but non-flag tasks [#{task_ids}] also have onComplete actions — players may advance the scenario without submitting VM flags. If VM completion is mandatory for this aim, ensure non-flag tasks do not independently unlock subsequent aims or tasks."
    end
  end

  # VM launcher reachability: technical challenge accessible without any physical lock
  vm_launcher_room_ids.each do |room_id|
    unless locked_room_ids.include?(room_id)
      issues << "💡 SUGGESTION: Room '#{room_id}' contains a VM launcher but the room itself is not locked — the technical challenge has no physical access barrier. Consider adding a door lock (rfid, key, or pin) to require players to gain physical access first, reinforcing the layered access control learning objective."
    end
  end

  # Provide best practice guidance for event-driven cutscenes
  if person_npcs_with_event_cutscenes.any?
    issues << "✅ GOOD PRACTICE: Scenario uses event-driven cutscene architecture with #{person_npcs_with_event_cutscenes.size} person-chat cutscene(s). Ensure corresponding phone NPCs use #set_global tags to trigger these cutscenes"
  end

  # Good practice confirmations
  if has_global_var_on_ko
    issues << "✅ GOOD PRACTICE: Scenario uses globalVarOnKO on NPCs — global variables are set when NPCs are knocked out, enabling event-driven story progression. Ensure all referenced variables are in globalVariables."
  end

  if has_skip_if_global
    issues << "✅ GOOD PRACTICE: Scenario uses timedConversation.skipIfGlobal — the opening briefing will not replay when the player resumes the scenario."
  end

  if collection_groups_used.any? && (collection_groups_used & target_groups_used).any?
    issues << "✅ GOOD PRACTICE: Scenario uses collection_group on items with matching task targetGroup — item collection progress is tracked correctly."
  end

  if has_music
    issues << "✅ GOOD PRACTICE: Scenario uses the music system — dynamic music changes based on in-game events significantly enhance immersion."
  end

  if has_launch_device
    issues << "✅ GOOD PRACTICE: Scenario uses a launch-device — this is a high-stakes interactive prop used for the mission climax. See scenarios/m01_first_contact/scenario.json.erb (derek_office) for a complete reference implementation."
  end

  if has_hostile_npcs
    issues << "✅ GOOD PRACTICE: Scenario uses hostile NPCs — this adds physical challenge and urgency. Ensure hostile NPCs have behavior.chaseSpeed, attackDamage, and pauseToAttack configured."
  end

  # Feature suggestions
  unless has_vm_launcher
    issues << "💡 SUGGESTION: Consider adding VM launcher terminals (type: 'vm-launcher') for hacking challenges. See scenarios/m01_first_contact/scenario.json.erb (server_room) for example"
  end

  unless has_flag_station
    issues << "💡 SUGGESTION: Consider adding flag station terminals (type: 'flag-station') for VM flag submission. See scenarios/m01_first_contact/scenario.json.erb (server_room) for example"
  end

  unless has_pc_with_files
    issues << "💡 SUGGESTION: Consider adding at least one PC container (type: 'pc') with files (type: 'text_file') in 'contents' array. Use collection_group on files and a matching targetGroup task to track reading progress. See scenarios/m01_first_contact/scenario.json.erb (it_room/kevin_office) for example"
  end

  unless has_phone_npc_with_messages || has_phone_npc_with_events
    issues << "💡 SUGGESTION: Consider adding at least one phone NPC (npcType: 'phone') with timedMessages and eventMappings. Phone NPCs are contacts in the player's phone that send messages, respond to events, and drive narrative. See scenarios/m01_first_contact/scenario.json.erb (agent_0x99) for a full example"
  end

  unless has_opening_cutscene
    issues << "💡 SUGGESTION: Consider adding an opening briefing cutscene — a person NPC with timedConversation (delay: 0, targetKnot: '...', skipIfGlobal: 'briefing_played', setGlobalOnStart: 'briefing_played') in the starting room. See scenarios/m01_first_contact/scenario.json.erb (briefing_cutscene) for example"
  end

  unless has_closing_debrief
    issues << "💡 SUGGESTION: Consider adding event-driven closing debrief cutscene using this architecture:"
    issues << "   1. Add global variable to scenario.globalVariables (e.g., 'start_debrief_cutscene': false)"
    issues << "   2. In phone NPC's Ink story, add tags: #set_global:start_debrief_cutscene:true and #exit_conversation"
    issues << "   3. Create person NPC with eventMappings: [{eventPattern: 'global_variable_changed:start_debrief_cutscene', condition: 'value === true', conversationMode: 'person-chat', targetKnot: 'start', background: 'assets/backgrounds/hq1.png', onceOnly: true}]"
    issues << "   4. Add behavior: {initiallyHidden: true} to person NPC so it doesn't appear in-world"
    issues << "   See scenarios/m01_first_contact/scenario.json.erb (closing_debrief_person) for complete reference implementation"
  end

  # Check for NPCs without waypoints
  if has_person_npcs && !has_npc_with_waypoints
    issues << "💡 SUGGESTION: Consider adding patrol waypoints to at least one person NPC for dynamic movement. Add behavior.patrol.waypoints array with {x, y} coordinates, or behavior.patrol.route for multi-room patrols. See scenarios/m01_first_contact/scenario.json.erb for NPCs with hostile behavior and movement."
  end

  # Check for phone contacts without timed messages
  if has_phone_contacts && !phone_npcs_without_messages.empty?
    npc_list = phone_npcs_without_messages.join(', ')
    issues << "💡 SUGGESTION: Consider adding timedMessages to phone contacts for narrative delivery — timed messages drive the story forward at key moments. Phone NPCs without timed messages: #{npc_list}. See scenarios/m01_first_contact/scenario.json.erb (agent_0x99) for example"
  end

  # Suggest variety in lock types
  if lock_types_used.size < 2
    issues << "💡 SUGGESTION: Consider adding variety in lock types — scenarios typically use 3+ different mechanisms (key, pin, rfid, password, flag). Currently using: #{lock_types_used.to_a.join(', ').then { |s| s.empty? ? 'none' : s }}. m01 uses all five lock types: key (doors/briefcases), pin (safes/cabinets), rfid (server room), password (computers), flag (encrypted archive). See scenarios/m01_first_contact/scenario.json.erb for examples"
  end

  # Suggest RFID locks
  unless has_rfid_lock
    issues << "💡 SUGGESTION: Consider adding RFID locks (lockType: 'rfid') for high-security areas. Requires an rfid_cloner tool and an NPC or item with a card_id. See scenarios/m01_first_contact/scenario.json.erb (server_room) for example"
  end

  # Suggest PIN locks
  unless has_pin_lock
    issues << "💡 SUGGESTION: Consider adding PIN locks (lockType: 'pin') for safes, cabinets, and doors — PIN codes are found as clues elsewhere in the scenario. See scenarios/m01_first_contact/scenario.json.erb (storage_safe, filing cabinets) for examples"
  end

  # Suggest password locks
  unless has_password_lock
    issues << "💡 SUGGESTION: Consider adding password locks (lockType: 'password') for computers and workstations — passwords are discovered through investigation. See scenarios/m01_first_contact/scenario.json.erb (derek_computer, kevin workstation) for examples"
  end

  # Suggest security tools
  unless has_security_tools
    issues << "💡 SUGGESTION: Consider adding security tools (lockpick, fingerprint_kit, pin-cracker, bluetooth_scanner, rfid_cloner) for interactive gameplay. In m01, a lockpick is held by kevin_park and obtained by defeating him, enabling key-locked doors. See scenarios/m01_first_contact/scenario.json.erb for examples"
  end

  # Suggest containers with contents
  unless has_container_with_contents
    issues << "💡 SUGGESTION: Consider adding containers (safe, bin, pc, briefcase, suitcase) with contents for hidden items and layered puzzle design. In m01, multiple safes and bins contain key evidence items. See scenarios/m01_first_contact/scenario.json.erb for examples"
  end

  # Suggest readable items
  unless has_readable_items
    issues << "💡 SUGGESTION: Consider adding readable items (notes, notes2, notes5, text_file) for storytelling and clues. Readable items with onRead.setVariable can trigger story events when a player reads them. See scenarios/m01_first_contact/scenario.json.erb for examples"
  end

  # Suggest music system
  unless has_music
    issues << "💡 SUGGESTION: Consider adding a 'music' section with events array to drive dynamic music changes. In m01, music changes when the briefing ends, when a threat is revealed, and when the debrief begins. See scenarios/m01_first_contact/scenario.json.erb for example"
  end

  # Suggest hostile NPCs
  unless has_hostile_npcs
    issues << "💡 SUGGESTION: Consider adding at least one hostile NPC (behavior: { hostile: true }) to create physical danger and tension. In m01, sarah_martinez, derek_lawson, and kevin_park are all hostile. See scenarios/m01_first_contact/scenario.json.erb for examples"
  end

  # Dungeon graph metadata
  if has_puzzle_graph_metadata
    issues << "✅ GOOD PRACTICE: Scenario uses puzzle_graph_* metadata — run 'ruby scripts/generate_dungeon_graph.rb scenarios/my_scenario/scenario.json.erb' to generate an interactive puzzle dependency graph."
  else
    issues << "💡 SUGGESTION: Consider adding puzzle_graph_unlocks to key items (clue notes inside locked containers, NPC-held keys, submit_flags tasks) to enable the dungeon graph generator. Run 'ruby scripts/generate_dungeon_graph.rb <scenario>' to visualise puzzle flow. See README_scenario_design.md §Dungeon Graph Metadata for field reference."
  end

  issues
end

# Check for recommended fields and return warnings
def check_recommended_fields(json_data)
  warnings = []

  # Top-level recommended fields
  warnings << "Missing recommended field: 'globalVariables' - useful for Ink dialogue state management" unless json_data.key?('globalVariables')
  warnings << "Missing recommended field: 'player' - player sprite configuration improves visual experience" unless json_data.key?('player')

  # Check for objectives with tasks (recommended for structured gameplay)
  if !json_data['objectives'] || json_data['objectives'].empty?
    warnings << "Missing recommended: 'objectives' array with tasks - helps structure gameplay and track progress"
  elsif json_data['objectives'].none? { |obj| obj['tasks'] && !obj['tasks'].empty? }
    warnings << "Missing recommended: objectives should include tasks - objectives without tasks don't provide clear goals"
  end

  # Track if there's at least one NPC with timed conversation (for cut-scenes)
  has_timed_conversation_npc = false

  # Check rooms
  if json_data['rooms']
    json_data['rooms'].each do |room_id, room|
      # Check room objects
      if room['objects']
        room['objects'].each_with_index do |obj, idx|
          path = "rooms/#{room_id}/objects[#{idx}]"
          # Skip observations warning for readable items that already provide their content via 'text'
          # (the text is the description; observations would be redundant)
          skip_obs = obj['readable'] && obj['text'] && !obj['text'].empty?
          unless obj.key?('observations') || skip_obs
            warnings << "Missing recommended field: '#{path}/observations' - helps players understand what items are"
          end
        end
      end


      # Check NPCs
      if room['npcs']
        room['npcs'].each_with_index do |npc, idx|
          path = "rooms/#{room_id}/npcs[#{idx}]"

          # Phone NPCs should have avatar
          if npc['npcType'] == 'phone' && !npc['avatar']
            warnings << "Missing recommended field: '#{path}/avatar' - phone NPCs should have avatar images"
          end

          # Person NPCs should have position (unless initiallyHidden — cutscene-only NPCs have no in-world sprite)
          if npc['npcType'] == 'person' && !npc['position'] && !npc['behavior']&.dig('initiallyHidden')
            warnings << "Missing recommended field: '#{path}/position' - person NPCs need x,y coordinates (unless behavior.initiallyHidden: true for cutscene-only NPCs)"
          end

          # NPCs with storyPath should have currentKnot
          if npc['storyPath'] && !npc['currentKnot']
            warnings << "Missing recommended field: '#{path}/currentKnot' - specifies starting dialogue knot"
          end

          # Check for NPCs without behavior (no storyPath, no timedMessages, no timedConversation, no eventMappings)
          has_behavior = npc['storyPath'] ||
                         (npc['timedMessages'] && !npc['timedMessages'].empty?) ||
                         npc['timedConversation'] ||
                         (npc['eventMappings'] && !npc['eventMappings'].empty?)

          unless has_behavior
            warnings << "Missing recommended: '#{path}' has no behavior - NPCs should have storyPath, timedMessages, timedConversation, or eventMappings"
          end

          # Track timed conversations (for cut-scene recommendation)
          if npc['timedConversation']
            has_timed_conversation_npc = true
          end
        end
      end
    end
  end

  # Check for at least one NPC with timed conversation (recommended for starting cut-scenes)
  unless has_timed_conversation_npc
    warnings << "Missing recommended: No NPCs with 'timedConversation' - consider adding one for immersive starting cut-scenes"
  end

  # Check objectives
  if json_data['objectives']
    json_data['objectives'].each_with_index do |objective, idx|
      path = "objectives[#{idx}]"
      warnings << "Missing recommended field: '#{path}/description' - helps players understand the objective" unless objective.key?('description')

      if objective['tasks']
        objective['tasks'].each_with_index do |task, task_idx|
          task_path = "#{path}/tasks[#{task_idx}]"
          # Tasks with targetCount should have showProgress
          if task['targetCount'] && !task['showProgress']
            warnings << "Missing recommended field: '#{task_path}/showProgress' - shows progress for collect_items tasks"
          end
        end
      end
    end
  end

  # Check startItemsInInventory
  if json_data['startItemsInInventory']
    json_data['startItemsInInventory'].each_with_index do |item, idx|
      path = "startItemsInInventory[#{idx}]"
      warnings << "Missing recommended field: '#{path}/observations' - helps players understand starting items" unless item.key?('observations')
    end
  end

  warnings
end

# Main execution
def main
  options = {
    schema_path: File.join(__dir__, 'scenario-schema.json'),
    verbose: false,
    output_json: false,
    no_graph: false,
    skip_ink: false
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} <scenario.json.erb> [options]"

    opts.on('-s', '--schema PATH', 'Path to JSON schema file') do |path|
      options[:schema_path] = path
    end

    opts.on('-v', '--verbose', 'Show detailed validation output') do
      options[:verbose] = true
    end

    opts.on('-o', '--output-json', 'Output the rendered JSON to stdout') do
      options[:output_json] = true
    end

    opts.on('--no-graph', 'Skip dungeon graph generation after validation') do
      options[:no_graph] = true
    end

    opts.on('--skip-ink', 'Skip ink file compilation validation (faster, but less thorough)') do
      options[:skip_ink] = true
    end

    opts.on('-h', '--help', 'Show this help message') do
      puts opts
      exit 0
    end
  end.parse!

  erb_path = ARGV[0]

  if erb_path.nil? || erb_path.empty?
    $stderr.puts "ERROR: No scenario.json.erb file specified"
    $stderr.puts "Usage: #{$PROGRAM_NAME} <scenario.json.erb> [options]"
    exit 1
  end

  erb_path = File.expand_path(erb_path)
  schema_path = File.expand_path(options[:schema_path])

  puts "Validating scenario: #{erb_path}"
  puts "Using schema: #{schema_path}"
  puts

  # Load valid item types from assets directory
  repo_root = File.expand_path('..', __dir__)
  valid_item_types = load_valid_item_types(repo_root)
  if valid_item_types
    puts "Loaded #{valid_item_types.size} valid item types from assets/objects/"
  else
    puts "⚠️ assets/objects/ directory not found — item type validation skipped"
  end
  puts

  begin
    # Render ERB to JSON
    puts "Rendering ERB template..."
    json_data = render_erb_to_json(erb_path)
    puts "✓ ERB rendered successfully"
    puts

    # Output JSON if requested
    if options[:output_json]
      puts "Rendered JSON:"
      puts JSON.pretty_generate(json_data)
      puts
    end

    # Pre-validate structure before running schema validation
    puts "Checking JSON structure..."
    structure_issues = check_structure_validity(json_data)

    # Report structure issues immediately and exit
    if !structure_issues.empty?
      puts "✗ Structure validation failed with #{structure_issues.length} error(s):"
      puts

      structure_issues.each_with_index do |issue, index|
        puts "#{index + 1}. #{issue}"
        puts
      end

      exit 1
    end
    puts "✓ JSON structure is valid"
    puts

    # Check ink files exist and compile (unless skipped)
    unless options[:skip_ink]
      puts "Checking ink files..."
      ink_issues = check_ink_files(json_data, repo_root)

      # Report ink issues immediately and exit if critical
      if ink_issues.any? { |issue| issue.start_with?("❌") }
        puts "✗ Ink file validation failed with #{ink_issues.count { |i| i.start_with?("❌") }} error(s):"
        puts

        ink_issues.each_with_index do |issue, index|
          puts "#{index + 1}. #{issue}"
          puts
        end

        exit 1
      elsif ink_issues.any?
        puts "⚠️ Found #{ink_issues.length} ink file warning(s):"
        puts

        ink_issues.each_with_index do |issue, index|
          puts "#{index + 1}. #{issue}"
          puts
        end
      else
        puts "✓ All ink files valid"
      end
      puts
    else
      puts "⏭️ Skipping ink file validation (--skip-ink)"
      puts
    end

    # Validate against schema
    puts "Validating against schema..."
    errors = validate_json(json_data, schema_path)

    # Check for common issues and structural problems
    puts "Checking for common issues..."
    common_issues = check_common_issues(json_data, valid_item_types)

    # Check for recommended fields
    puts "Checking recommended fields..."
    warnings = check_recommended_fields(json_data)

    # Report errors
    if errors.empty?
      puts "✓ Schema validation passed!"
    else
      puts "✗ Schema validation failed with #{errors.length} error(s):"
      puts

      errors.each_with_index do |error, index|
        puts "#{index + 1}. #{error}"
        puts
      end

      if options[:verbose]
        puts "Full JSON structure:"
        puts JSON.pretty_generate(json_data)
      end

      exit 1
    end

    # Report common issues
    if common_issues.empty?
      puts "✓ No common issues found."
      puts
    else
      puts "⚠️ Found #{common_issues.length} issue(s) and suggestion(s):"
      puts

      common_issues.each_with_index do |issue, index|
        puts "#{index + 1}. #{issue}"
      end
      puts
    end

    # Report warnings
    if warnings.empty?
      puts "✓ No missing recommended fields."
      puts
    else
      puts "⚠️ Found #{warnings.length} missing recommended field(s):"
      puts

      warnings.each_with_index do |warning, index|
        puts "#{index + 1}. #{warning}"
      end
      puts
    end

    # Generate dungeon graph (runs by default, suppress with --no-graph)
    unless options[:no_graph]
      graph_script = File.join(__dir__, 'generate_dungeon_graph.rb')
      if File.exist?(graph_script)
        puts "Generating dungeon graph..."
        result = system('ruby', graph_script, erb_path)
        graph_out = File.join(File.dirname(erb_path), 'dungeon_graph.html')
        if result
          puts "✓ Dungeon graph: #{graph_out}"
        else
          puts "⚠️ Dungeon graph generation failed (non-fatal)"
        end
        puts
      end
    end

    # Exit with success (warnings don't cause failure)
    puts "✓ Validation complete!"
    exit 0
  rescue StandardError => e
    $stderr.puts "ERROR: #{e.message}"
    if options[:verbose]
      $stderr.puts e.backtrace.join("\n")
    end
    exit 1
  end
end

main if __FILE__ == $PROGRAM_NAME
