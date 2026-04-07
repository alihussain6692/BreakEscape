#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates scenarios/<name>/dungeon_graph.html from a scenario.json.erb
# Uses Mermaid.js (CDN) for automatic dependency-graph layout.
#
# Usage:
#   ruby scripts/generate_dungeon_graph.rb scenarios/m01_first_contact/scenario.json.erb

require 'erb'
require 'json'
require 'base64'
require 'securerandom'
require 'set'

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
LOCK_TYPE_LABELS = {
  'pin'      => 'PIN lock',
  'keycard'  => 'Keycard lock',
  'rfid'     => 'RFID lock',
  'key'      => 'Key lock',
  'biometric' => 'Biometric lock',
  'flag'     => 'Flag lock',
  'password' => 'Password lock',
  'lockpick' => 'Pick the lock',
}.freeze

SCENARIO_FILE = ARGV[0] or abort "Usage: ruby scripts/generate_dungeon_graph.rb <scenario.json.erb>"
OUT_FILE      = File.join(File.dirname(SCENARIO_FILE), 'dungeon_graph.html')
SCENARIO_ID   = File.basename(File.dirname(SCENARIO_FILE))

# ---------------------------------------------------------------------------
# ERB context — replicates app/models/break_escape/mission.rb ScenarioBinding
# ---------------------------------------------------------------------------
class ScenarioBinding
  def initialize
    @random_password = SecureRandom.alphanumeric(8)
    @random_pin      = rand(1000..9999).to_s
    @random_code     = SecureRandom.hex(4)
  end

  attr_reader :random_password, :random_pin, :random_code

  def vm_context
    nil
  end

  def vm_object(_title, fallback = {})
    fallback.to_json
  end

  def flags_for_vm(_vm, fallback = [])
    fallback.to_json
  end

  def vm_flags_json(_vm, fallback = [])
    fallback.to_json
  end

  def get_binding
    binding
  end
end

# ---------------------------------------------------------------------------
# Parse
# ---------------------------------------------------------------------------
src      = File.read(SCENARIO_FILE)
rendered = ERB.new(src).result(ScenarioBinding.new.get_binding)
scenario = JSON.parse(rendered)

# ---------------------------------------------------------------------------
# Graph state
# ---------------------------------------------------------------------------
$nodes   = {}  # id => { label:, klass:, optional: }
$edges   = []  # { from:, to:, dashed:, label: }
$and_idx = 0

# Sanitise a string to a valid Mermaid node identifier
def nid(s)
  s.to_s.downcase.gsub(/[^a-z0-9]/, '_').gsub(/_+/, '_').sub(/\A_+/, '').sub(/_+\z/, '')
end

def add_node(id, label, klass, optional: false)
  $nodes[id] ||= { label: label.to_s, klass: klass.to_s, optional: optional }
  id
end

def add_edge(from, to, dashed: false, label: nil)
  return unless from && to && from != to
  $edges << { from: from, to: to, dashed: dashed, label: label }
end

# ---------------------------------------------------------------------------
# Room door-lock and room nodes for locked rooms
# ---------------------------------------------------------------------------
rooms = scenario['rooms'] || {}

def room_label(room_id, room)
  room['door_sign'] || room_id.tr('_', ' ').split.map(&:capitalize).join(' ')
end

rooms.each do |room_id, room|
  next unless room['locked']
  type_str = LOCK_TYPE_LABELS[room['lockType']] || 'Lock'
  sign     = room_label(room_id, room)
  add_node("door_#{room_id}", "#{sign}<br/>#{type_str}", 'lock')
  add_node(room_id, sign, 'room')
  add_edge("door_#{room_id}", room_id)
end

# ---------------------------------------------------------------------------
# Resolve a puzzle_graph_unlocks target to a node id, creating it if needed
# ---------------------------------------------------------------------------
def resolve_target(target, rooms)
  if rooms.key?(target)
    if rooms[target]['locked']
      "door_#{target}"
    else
      sign = room_label(target, rooms[target])
      add_node(target, sign, 'room')
      target
    end
  else
    lock_id = "lock_#{nid(target)}"
    unless $nodes.key?(lock_id)
      label = target.tr('_', ' ').split.map(&:capitalize).join(' ')
      add_node(lock_id, label, 'lock')
    end
    lock_id
  end
end

# ---------------------------------------------------------------------------
# Recursive object walker — collects puzzle_graph_* items
# ---------------------------------------------------------------------------
$and_pending = []  # [{item_id:, tool_key:, targets:, optional:}]

def walk_objects(objects, source_id, rooms)
  (objects || []).each do |obj|
    obj_id   = obj['id'] || nid((obj['name'] || obj['type']).to_s)
    obj_name = obj['name'] || obj_id.tr('_', ' ').split.map(&:capitalize).join(' ')

    # Locked container → create lock node, recurse into contents
    if obj['locked'] && obj['contents']
      lock_id  = "lock_#{obj_id}"
      type_str = LOCK_TYPE_LABELS[obj['lockType']] || 'Lock'
      add_node(lock_id, "#{obj_name}<br/>#{type_str}", 'lock')
      add_edge(source_id, lock_id)
      walk_objects(obj['contents'], lock_id, rooms)
    elsif obj['contents']
      walk_objects(obj['contents'], source_id, rooms)
    end

    pg_unlocks = obj['puzzle_graph_unlocks']
    pg_role    = obj['puzzle_graph_role']
    pg_opt     = obj['puzzle_graph_optional'] == true
    pg_and     = obj['puzzle_graph_and_with']

    next unless pg_unlocks || pg_role

    item_id = nid(obj_name)
    klass   = case obj['type']
              when 'key', 'keycard', 'lockpick' then 'key'
              else 'item'
              end

    add_node(item_id, obj_name, klass, optional: pg_opt)
    add_edge(source_id, item_id, dashed: pg_opt)

    if pg_and && pg_unlocks
      $and_pending << {
        item_id:  item_id,
        tool_key: pg_and,
        targets:  Array(pg_unlocks),
        optional: pg_opt
      }
    elsif pg_unlocks
      Array(pg_unlocks).each do |target|
        target_node = resolve_target(target, rooms)
        add_edge(item_id, target_node, dashed: pg_opt)
      end
    end
  end
end

# Walk all rooms: objects then NPC itemsHeld
rooms.each do |room_id, room|
  # Ensure room node exists when objects are found in it
  add_node(room_id, room_label(room_id, room), 'room') if (room['objects'] || []).any? { |o|
    o['puzzle_graph_unlocks'] || o['puzzle_graph_role'] ||
    (o['contents'] || []).any? { |c| c['puzzle_graph_unlocks'] || c['puzzle_graph_role'] }
  }

  walk_objects(room['objects'], room_id, rooms)

  (room['npcs'] || []).each do |npc|
    items = npc['itemsHeld'] || []
    next unless items.any? { |i| i['puzzle_graph_unlocks'] || i['puzzle_graph_role'] }

    npc_display = npc['displayName'] || npc['name'] || npc['id'].to_s
    npc_nid     = "npc_#{nid(npc_display)}"
    add_node(npc_nid, npc_display, 'key')
    add_node(room_id, room_label(room_id, room), 'room')
    add_edge(room_id, npc_nid)
    walk_objects(items, npc_nid, rooms)
  end
end

# ---------------------------------------------------------------------------
# Resolve AND-gates
# Group by (tool_key + sorted targets) so the same gate is reused when
# the same tool decodes multiple notes pointing to the same locks.
# ---------------------------------------------------------------------------
gate_map = {}  # gate_key => gate_node_id

$and_pending.each do |entry|
  gate_key = "#{entry[:tool_key]}|#{entry[:targets].sort.join(',')}"

  unless gate_map[gate_key]
    $and_idx += 1
    gate_id  = "andgate#{$and_idx}"
    add_node(gate_id, '+', 'gate')

    # Tool → gate (dashed — tool is a helper, not consumed)
    tool_node = nid(entry[:tool_key])
    add_edge(tool_node, gate_id, dashed: true)

    # Gate → each unlock target
    entry[:targets].each do |target|
      add_edge(gate_id, resolve_target(target, rooms))
    end

    gate_map[gate_key] = gate_id
  end

  # Note item → gate
  add_edge(entry[:item_id], gate_map[gate_key])
end

# ---------------------------------------------------------------------------
# VM challenges from objectives
# ---------------------------------------------------------------------------
vm_challenge_ids = []
prev_flag_id     = nil

(scenario['objectives'] || []).each do |obj_block|
  (obj_block['tasks'] || []).each do |task|
    next unless task['type'] == 'submit_flags'

    task_id = task['taskId'] || "challenge_#{vm_challenge_ids.size + 1}"
    cid    = "vmch_#{nid(task_id)}"
    flid   = "vmfl_#{nid(task_id)}"
    clabel = task['title'] || task_id.tr('_', ' ').split.map(&:capitalize).join(' ')
    flabel = task_id.sub(/\Asubmit_/, '').sub(/_flag\z/, '').tr('_', ' ').split.map(&:capitalize).join(' ') + ' Flag'

    add_node(cid,  clabel, 'vm')
    add_node(flid, flabel, 'flag')
    add_edge(cid,  flid)
    add_edge(prev_flag_id, cid, dashed: true) if prev_flag_id

    if (pg_unlocks = task['puzzle_graph_unlocks'])
      Array(pg_unlocks).each { |t| add_edge(flid, resolve_target(t, rooms)) }
    end

    vm_challenge_ids << cid
    prev_flag_id = flid
  end
end

# Connect VM launcher lock node to first VM challenge
vm_lock_id = 'lock_vm_launcher_intro_linux'
if $nodes.key?(vm_lock_id)
  # Override label now we know intent
  $nodes[vm_lock_id][:label] = "VM Access Terminal<br/>SSH credentials needed"
  add_edge(vm_lock_id, vm_challenge_ids.first) if vm_challenge_ids.any?

  # Anchor to the room containing the physical vm-launcher object
  rooms.each do |room_id, room|
    if (room['objects'] || []).any? { |o| o['id'] == 'vm_launcher_intro_linux' }
      add_node(room_id, room_label(room_id, room), 'room')
      add_edge(room_id, vm_lock_id)
      break
    end
  end
end

# ---------------------------------------------------------------------------
# Room-to-room connections (physical layout)
# Locked destinations are skipped — their access is shown via the key chain.
# Open connections are shown once per pair (sorted dedup).
# ---------------------------------------------------------------------------
seen_room_pairs = Set.new

rooms.each do |room_id, room|
  add_node(room_id, room_label(room_id, room), 'room')

  (room['connections'] || {}).each_value do |dest|
    Array(dest).each do |dest_id|
      # Locked destination — access already shown via key/puzzle chain
      next if rooms.dig(dest_id, 'locked')

      pair_key = [room_id, dest_id].sort.join('|')
      next if seen_room_pairs.include?(pair_key)
      seen_room_pairs << pair_key

      if rooms.key?(dest_id)
        add_node(dest_id, room_label(dest_id, rooms[dest_id]), 'room')
      else
        add_node(dest_id, dest_id.tr('_', ' ').split.map(&:capitalize).join(' '), 'room')
      end

      add_edge(room_id, dest_id)
    end
  end
end

# ---------------------------------------------------------------------------
# Prune nodes that ended up with no edges (never connected to anything)
# ---------------------------------------------------------------------------
connected = Set.new($edges.flat_map { |e| [e[:from], e[:to]] })
$nodes.reject! { |id, n| n[:klass] == 'room' && !connected.include?(id) }
$edges.reject! { |e| !$nodes.key?(e[:from]) || !$nodes.key?(e[:to]) }

# ---------------------------------------------------------------------------
# Build Aim (story) graph
# ---------------------------------------------------------------------------
aim_nodes    = {}
aim_edges    = []
aim_edge_set = Set.new

(scenario['objectives'] || []).each do |aim|
  aid = "aim_#{nid(aim['aimId'])}"
  aim_nodes[aid] = {
    label:    aim['title'],
    klass:    'aim',
    optional: aim['optional'] == true,
    order:    aim['order'] || 0
  }
end

(scenario['objectives'] || []).each do |aim|
  aid  = "aim_#{nid(aim['aimId'])}"
  cond = aim['unlockCondition']

  if cond&.key?('aimCompleted')
    prev = "aim_#{nid(cond['aimCompleted'])}"
    key  = "#{prev}|#{aid}"
    unless aim_edge_set.include?(key)
      aim_edges << { from: prev, to: aid, dashed: true }
      aim_edge_set << key
    end
  elsif cond&.key?('aimsCompleted')
    gate_id = "aim_andgate_#{nid(aim['aimId'])}"
    aim_nodes[gate_id] = { label: '+', klass: 'aim_gate', optional: false }
    cond['aimsCompleted'].each do |a|
      from_id = "aim_#{nid(a)}"
      key     = "#{from_id}|#{gate_id}"
      unless aim_edge_set.include?(key)
        aim_edges << { from: from_id, to: gate_id, dashed: false }
        aim_edge_set << key
      end
    end
    key2 = "#{gate_id}|#{aid}"
    unless aim_edge_set.include?(key2)
      aim_edges << { from: gate_id, to: aid, dashed: false }
      aim_edge_set << key2
    end
  end

  (aim['tasks'] || []).each do |task|
    next unless (ua = task.dig('onComplete', 'unlockAim'))
    to_id = "aim_#{nid(ua)}"
    next if to_id == aid  # skip self-referential onComplete (aim activating itself)
    key   = "#{aid}|#{to_id}"
    unless aim_edge_set.include?(key)
      aim_edges << { from: aid, to: to_id, dashed: true }
      aim_edge_set << key
    end
  end
end

# ---------------------------------------------------------------------------
# Integrated graph: puzzle + aims + bridge edges
# ---------------------------------------------------------------------------
int_nodes    = $nodes.merge(aim_nodes)
int_edges    = $edges.dup + aim_edges.dup
int_edge_set = Set.new(int_edges.map { |e| "#{e[:from]}|#{e[:to]}" })

add_bridge = lambda do |from_id, to_id, dashed: true|
  return unless from_id && to_id && from_id != to_id
  return unless int_nodes.key?(from_id) && int_nodes.key?(to_id)
  key = "#{from_id}|#{to_id}"
  return if int_edge_set.include?(key)
  int_edges << { from: from_id, to: to_id, dashed: dashed }
  int_edge_set << key
end

(scenario['objectives'] || []).each do |aim|
  aid = "aim_#{nid(aim['aimId'])}"

  (aim['tasks'] || []).each do |task|
    task_type   = task['type']
    target_room = task['targetRoom']
    target_obj  = task['targetObject']

    # enter_room / unlock_room → locked door or room node is a prereq for this aim
    if %w[enter_room unlock_room].include?(task_type) && target_room
      door_id = "door_#{target_room}"
      if int_nodes.key?(door_id)
        add_bridge.call(door_id, aid)
      elsif int_nodes.key?(target_room)
        add_bridge.call(target_room, aid)
      end
    end

    # unlock_object → the object's lock node is a prereq for this aim
    if task_type == 'unlock_object' && target_obj
      lock_id = "lock_#{nid(target_obj)}"
      add_bridge.call(lock_id, aid) if int_nodes.key?(lock_id)
    end

    # collect_items with targetItemIds → each item node is a prereq (OR condition)
    Array(task['targetItemIds']).each do |item_id|
      add_bridge.call(nid(item_id), aid)
    end

    # onComplete.unlockAim — task completion triggers NEXT aim's unlock
    next unless (ua = task.dig('onComplete', 'unlockAim'))
    to_id = "aim_#{nid(ua)}"
    next if to_id == aid

    tid = task['taskId'] || ''
    add_bridge.call("vmfl_#{nid(tid)}", to_id)
    add_bridge.call(target_room, to_id) if target_room
  end
end

# ---------------------------------------------------------------------------
# Critical path (longest path in aim DAG)
# ---------------------------------------------------------------------------
def longest_path_in_dag(nodes, edges)
  adj    = Hash.new { |h, k| h[k] = [] }
  in_deg = Hash.new(0)
  nodes.each_key { |id| in_deg[id] = 0 unless in_deg.key?(id) }
  edges.each do |e|
    next unless nodes.key?(e[:from]) && nodes.key?(e[:to])
    adj[e[:from]] << e[:to]
    in_deg[e[:to]] += 1
  end

  queue = in_deg.select { |_, d| d == 0 }.keys.sort
  topo  = []
  until queue.empty?
    u = queue.shift
    topo << u
    adj[u].sort.each do |v|
      in_deg[v] -= 1
      queue << v if in_deg[v] == 0
    end
  end

  dist   = Hash.new(0)
  parent = {}
  topo.each do |u|
    adj[u].each do |v|
      if dist[u] + 1 > dist[v]
        dist[v]   = dist[u] + 1
        parent[v] = u
      end
    end
  end

  sink = nodes.key?('aim_close_the_case') ? 'aim_close_the_case' : dist.max_by { |_, v| v }&.first
  path = []
  n    = sink
  while n
    path.unshift(n)
    n = parent[n]
  end
  [path, dist[sink] || 0]
end

critical_path, critical_length = longest_path_in_dag(aim_nodes, aim_edges)
critical_set = Set.new(critical_path)

# ---------------------------------------------------------------------------
# Mermaid emitter (shared by puzzle / story / integrated tabs)
# ---------------------------------------------------------------------------
def emit_mermaid_diagram(nodes, edges, critical_set: Set.new)
  lines = ['flowchart TD', '']
  lines << '  classDef room      fill:#0f2d2d,stroke:#22ddcc,color:#a0ffee'
  lines << '  classDef lock      fill:#2d0f0f,stroke:#e66060,color:#ffa0a0'
  lines << '  classDef key       fill:#2d0812,stroke:#e66060,color:#ffa0a0'
  lines << '  classDef item      fill:#2d1200,stroke:#e89030,color:#ffcc80'
  lines << '  classDef gate      fill:#111,stroke:#666,color:#eee'
  lines << '  classDef vm        fill:#0c1f40,stroke:#4a90d9,color:#a0c8ff'
  lines << '  classDef flag      fill:#1a0c2d,stroke:#9060d0,color:#cc99ff'
  lines << '  classDef aim       fill:#0d2a0d,stroke:#44cc44,color:#88ff88'
  lines << '  classDef aim_gate  fill:#111111,stroke:#44cc44,color:#44cc44'
  lines << '  classDef critical  fill:#2a1500,stroke:#ffaa00,color:#ffdd88'
  lines << ''

  nodes.each do |id, n|
    lbl   = n[:label].to_s.gsub('"', "'")
    klass = n[:klass].to_s
    shape = case klass
            when 'room'                then "(\"#{lbl}\")"
            when 'lock', 'vm'          then "[\"#{lbl}\"]"
            when 'key', 'item', 'flag' then "{\"#{lbl}\"}"
            when 'gate', 'aim_gate'    then "((\" + \"))"
            when 'aim'                 then "{{\"#{lbl}\"}}"
            else                            "(\"#{lbl}\")"
            end
    lines << "  #{id}#{shape}"
  end
  lines << ''

  edges.each do |e|
    arr  = e[:dashed] ? '-.->' : '-->'
    elbl = e[:label] ? "|#{e[:label]}|" : ''
    lines << "  #{e[:from]} #{arr}#{elbl} #{e[:to]}"
  end
  lines << ''

  effective = nodes.to_h { |id, n| [id, critical_set.include?(id) ? 'critical' : n[:klass].to_s] }
  effective.group_by { |_, k| k }.each do |klass, grp|
    lines << "  class #{grp.map(&:first).join(',')} #{klass}"
  end

  opt_ids = nodes.reject { |id, _| critical_set.include?(id) }.select { |_, n| n[:optional] }.keys
  unless opt_ids.empty?
    lines << ''
    lines << '  classDef optional stroke-dasharray:5 2'
    lines << "  class #{opt_ids.join(',')} optional"
  end

  lines.join("\n")
end

def js_escape_mermaid(src)
  src.gsub('`') { '\`' }.gsub('${') { '\${' }
end

mermaid_puzzle     = emit_mermaid_diagram($nodes, $edges)
mermaid_story      = emit_mermaid_diagram(aim_nodes,  aim_edges,  critical_set: critical_set)
mermaid_integrated = emit_mermaid_diagram(int_nodes,  int_edges,  critical_set: critical_set)

# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------
total_aims     = (scenario['objectives'] || []).size
total_tasks    = (scenario['objectives'] || []).sum { |a| (a['tasks'] || []).size }
optional_tasks = (scenario['objectives'] || []).sum { |a| (a['tasks'] || []).count { |t| t['optional'] } }
vm_tasks       = (scenario['objectives'] || []).sum { |a| (a['tasks'] || []).count { |t| t['type'] == 'submit_flags' } }
and_gates_n    = (scenario['objectives'] || []).count { |a| a.dig('unlockCondition', 'aimsCompleted') }
lock_count     = $nodes.count { |_, n| n[:klass] == 'lock' }
room_count     = $nodes.count { |_, n| n[:klass] == 'room' }

path_labels = critical_path.map { |id|
  (aim_nodes[id] || {})[:label] || id.sub(/\Aaim_andgate_/, '+ ').sub(/\Aaim_/, '').tr('_', ' ').split.map(&:capitalize).join(' ')
}.join(' → ')

# ---------------------------------------------------------------------------
# HTML wrapper — 3 tabs (Puzzle / Story Aims / Story + Puzzle) + stats panel
# ---------------------------------------------------------------------------
brief = (scenario['scenario_brief'] || SCENARIO_ID).to_s[0, 120]
html  = <<~HTML
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <title>#{SCENARIO_ID} — Dungeon Graph</title>
    <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
    <style>
      *, *::before, *::after { box-sizing: border-box; }
      body       { background: #0a0f0f; color: #ccc; font-family: monospace; margin: 0; padding: 16px; }
      h1         { font-size: 13px; color: #22ddcc; margin: 0 0 4px; text-transform: uppercase; letter-spacing: 1px; }
      p.sub      { font-size: 11px; color: #555; margin: 0 0 12px; }
      .tab-bar   { display: flex; gap: 3px; margin-bottom: 0; border-bottom: 2px solid #1a3030; }
      .tab-bar button {
        background: #111e1e; color: #557; border: 1px solid #1a3030; border-bottom: none;
        padding: 6px 16px; font-family: monospace; font-size: 11px; cursor: pointer;
        text-transform: uppercase; letter-spacing: 1px; position: relative; top: 2px;
      }
      .tab-bar button.active  { background: #0a1a1a; color: #22ddcc; border-color: #22ddcc; border-bottom: 2px solid #0a1a1a; }
      .tab-bar button:hover:not(.active) { background: #141f1f; color: #aaa; }
      .wrap      { overflow: auto; background: #0a1a1a; padding: 12px; min-height: 200px; border: 1px solid #1a3030; border-top: none; }
      .stats     { margin-top: 20px; border-top: 2px solid #1a3030; padding-top: 14px; }
      .stats h2  { font-size: 12px; color: #22ddcc; text-transform: uppercase; letter-spacing: 1px; margin: 0 0 8px; }
      .crit-path { font-size: 11px; color: #ffdd88; background: #111; border: 1px solid #333; padding: 8px 12px; margin-bottom: 10px; overflow-x: auto; white-space: nowrap; }
      .note-oos  { font-size: 11px; color: #a0a040; border-left: 2px solid #555; padding: 4px 8px; margin-bottom: 12px; }
      table      { border-collapse: collapse; font-size: 11px; }
      td, th     { padding: 3px 14px 3px 0; text-align: left; }
      th         { color: #22ddcc; font-weight: normal; }
      td.val     { color: #ffcc80; }
    </style>
  </head>
  <body>
    <h1>#{SCENARIO_ID} — dependency graph</h1>
    <p class="sub">#{brief}</p>
    <div class="tab-bar">
      <button class="tab-btn active" data-tab="puzzle"     onclick="showTab('puzzle',this)">Puzzle Graph</button>
      <button class="tab-btn"        data-tab="story"      onclick="showTab('story',this)">Story Aims</button>
      <button class="tab-btn"        data-tab="integrated" onclick="showTab('integrated',this)">Story + Puzzle</button>
    </div>
    <div class="wrap" id="diagram-wrap">
      <p style="color:#555;font-size:11px">Loading…</p>
    </div>

    <div class="stats">
      <h2>Critical Path — #{critical_length} hops</h2>
      <div class="crit-path">#{path_labels}</div>
      <div class="note-oos">
        ⚠️&nbsp; Dashed aim arrows = narrative unlock only. A player with physical access to a room may complete an
        objective before the system unlocks that aim. Solid arrows indicate hard dependencies (AND gates, physical
        puzzle-lock chains). The critical path above shows the minimum mandatory sequence to reach mission completion.
      </div>
      <table>
        <tr><th>Aims (story objectives)</th><td class="val">#{total_aims}</td></tr>
        <tr><th>Total tasks</th><td class="val">#{total_tasks}</td></tr>
        <tr><th>Optional tasks</th><td class="val">#{optional_tasks} / #{total_tasks}</td></tr>
        <tr><th>VM flag challenges</th><td class="val">#{vm_tasks}</td></tr>
        <tr><th>AND-gate convergences</th><td class="val">#{and_gates_n}</td></tr>
        <tr><th>Physical locks (puzzle)</th><td class="val">#{lock_count}</td></tr>
        <tr><th>Rooms</th><td class="val">#{room_count}</td></tr>
        <tr><th>Puzzle nodes / edges</th><td class="val">#{$nodes.size} / #{$edges.size}</td></tr>
        <tr><th>Story nodes / edges</th><td class="val">#{aim_nodes.size} / #{aim_edges.size}</td></tr>
      </table>
    </div>

    <script>
      mermaid.initialize({ startOnLoad: false, theme: 'dark', flowchart: { curve: 'basis', htmlLabels: true } });

      const diagrams = {
        puzzle:     \`#{js_escape_mermaid(mermaid_puzzle)}\`,
        story:      \`#{js_escape_mermaid(mermaid_story)}\`,
        integrated: \`#{js_escape_mermaid(mermaid_integrated)}\`
      };
      const rendered = {};
      let seq = 0;

      async function showTab(name, btn) {
        document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
        (btn || document.querySelector('.tab-btn[data-tab="' + name + '"]')).classList.add('active');
        const wrap = document.getElementById('diagram-wrap');
        if (!rendered[name]) {
          wrap.innerHTML = '<p style="color:#555;font-size:11px">Rendering\u2026</p>';
          try {
            const { svg } = await mermaid.render('diag_' + name + '_' + (++seq), diagrams[name]);
            rendered[name] = svg;
          } catch(e) {
            rendered[name] = '<pre style="color:#f66;font-size:10px">Render error: ' + e.message + '</pre>';
          }
        }
        wrap.innerHTML = rendered[name];
      }
      showTab('puzzle');
    </script>
  </body>
  </html>
HTML

File.write(OUT_FILE, html)
puts "Written: #{OUT_FILE}"
puts "Puzzle     — Nodes: #{$nodes.size}  Edges: #{$edges.size}"
puts "Story      — Nodes: #{aim_nodes.size}  Edges: #{aim_edges.size}"
puts "Integrated — Nodes: #{int_nodes.size}  Edges: #{int_edges.size}"
puts "Critical path (#{critical_length} hops): #{path_labels}"
