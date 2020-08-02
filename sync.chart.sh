# shellcheck shell=bash
# no need for shebang - this file is loaded from charts.d.plugin
# update_every is a special variable - it holds the number of seconds
# between the calls of the _update() function
sync_update_every=3

# the priority is used to sort the charts on the dashboard
# 1 = the first chart
sync_priority=150000

# to enable this chart, you have to set this to 12345
# (just a demonstration for something that needs to be checked)
sync_magic_number=12345

# global variables to store our collected data
# remember: they need to start with the module name sync_
sync_current_round_node_0=
sync_synced_round_node_0=
sync_current_round_node_1=
sync_synced_round_node_1=
sync_current_round_node_2=
sync_synced_round_node_2=

sync_get() {

  # node 0
  node_status="$( curl -s http://localhost:8080/node/status )"
  sync_current_round_node_0="$( echo $node_status | jq -r .data.metrics.erd_current_round )"
  sync_synced_round_node_0="$( echo $node_status | jq -r .data.metrics.erd_synchronized_round )"

  # node 1
  node_status="$( curl -s http://localhost:8081/node/status )"
  sync_current_round_node_1="$( echo $node_status | jq -r .data.metrics.erd_current_round )"
  sync_synced_round_node_1="$( echo $node_status | jq -r .data.metrics.erd_synchronized_round )"

  # node 2
  node_status="$( curl -s http://localhost:8082/node/status )"
  sync_current_round_node_2="$( echo $node_status | jq -r .data.metrics.erd_current_round )"
  sync_synced_round_node_2="$( echo $node_status | jq -r .data.metrics.erd_synchronized_round )"

  # this should return:
  #  - 0 to send the data to netdata
  #  - 1 to report a failure to collect the data
  return 0
}

# _check is called once, to find out if this chart should be enabled or not
sync_check() {
  # this should return:
  #  - 0 to enable the chart
  #  - 1 to disable the chart

  # check something
  [ "${sync_magic_number}" != "12345" ] && error "manual configuration required: you have to set sync_magic_number=$sync_magic_number in example.conf to start example chart." && return 1

  # check for required commands
  require_cmd curl || return 1
  require_cmd jq || return 1

  # check that we can collect data
  sync_get || return 1

  return 0
}

# _create is called once, to create the charts
sync_create() {
  # create the chart with 3 dimensions
  cat << EOF
CHART elrond.sync.node0 '' "Node 0 sync" "round" elrond synccontext line $((sync_priority + 0)) $sync_update_every
DIMENSION current.node 'Current' absolute 1 1
DIMENSION synced.node  'Synced' absolute 1 1
CHART elrond.sync.node1 '' "Node 1 sync" "round" elrond synccontext line $((sync_priority + 1)) $sync_update_every
DIMENSION current.node 'Current' absolute 1 1
DIMENSION synced.node  'Synced' absolute 1 1
CHART elrond.sync.node2 '' "Node 2 sync" "round" elrond synccontext line $((sync_priority + 2)) $sync_update_every
DIMENSION current.node 'Current' absolute 1 1
DIMENSION synced.node  'Synced' absolute 1 1
EOF

  return 0
}

# _update is called continuously, to collect the values
sync_update() {
  # the first argument to this function is the microseconds since last update
  # pass this parameter to the BEGIN statement (see bellow).

  sync_get || return 1

  # write the result of the work.
  cat << VALUESEOF
BEGIN elrond.sync.node0 $1
SET current.node = $sync_current_round_node_0
SET synced.node = $sync_synced_round_node_0
END
BEGIN elrond.sync.node1 $1
SET current.node = $sync_current_round_node_1
SET synced.node = $sync_synced_round_node_1
END
BEGIN elrond.sync.node2 $1
SET current.node = $sync_current_round_node_2
SET synced.node = $sync_synced_round_node_2
END
VALUESEOF

  return 0
}
