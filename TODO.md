# TO-DO List

## Unresolved issues

1. Correct way to handle Neovim existing on remote machine
2. Correct way to handle detaching the Remote Neovim server from the remote instance
3. Add CONTRIBUTING.md

## Backlog

1. Use `plenary.async`

## To do

- Add tests for the added code
  - Progress view
    01. For `_set_buffer`, buffer is set
    02. `_set_top_line` sets the buffer's top line correctly
    03. `:show()` sets the current window
    04. `:_collapse_all_nodes()`. Ensure all nodes are collapsed
    05. `:_expand_all_nodes()`. Ensure all nodes are expanded
    06. `:add_session_node` adds a node for each type at correct point
    07. `:start_run` adds a `run_node`
    08. `_initialize_session_info_tree` adds 3 nodes
    09. `:add_progress_node` adds correct node for each type at correct mount point
    10. `:update_status` updates parent_status and node status when needed;
    11. `:update_status` correct node is collapsed on success or expanded
    12. `_add_progress_view_section` expands correct segment, collapses previous
        segment
    13. `add_progress_view_run_section` collapses all nodes and expands current one
    14. `add_output_node` adds the node
- Update README.md
  - Mention that when changing `progress_view` params, respect nui documentation
  - Add info about ":RemoteInfo"
  - Add how ":RemoteStart" behaves
    - Explain the 4 choices that you have
    - Explain local client launch behaviour when server is not running
  - Add more information about callback
  - Add deprecated to heading of ":RemoteSessionInfo"
