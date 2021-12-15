using Graphs, GraphsFlows

# a large number to prevent this edge being a cut
MAX_WEIGHT = 100000

function mincut_inds_binary_tree(network::Vector{ITensor}, uncontract_inds::Vector)
  edge_dict = Dict()
  # only go over contracted inds
  contract_edges = []
  for (i, t) in enumerate(network)
    for ind in setdiff(inds(t), uncontract_inds)
      if !haskey(edge_dict, ind)
        edge_dict[ind] = (i, log2(space(ind)))
      else
        @assert(length(edge_dict[ind]) == 2)
        edge_dict[ind] = (edge_dict[ind][1], i, edge_dict[ind][2])
        push!(contract_edges, edge_dict[ind])
      end
    end
  end
  graph = Graphs.DiGraph(length(network))
  capacity_matrix = zeros(length(network), length(network))
  for e in contract_edges
    u, v, f = e
    Graphs.add_edge!(graph, u, v)
    Graphs.add_edge!(graph, v, u)
    capacity_matrix[u, v] = f
    capacity_matrix[v, u] = f
  end
  # update uncontract inds
  grouped_uncontracted_inds = []
  for (i, t) in enumerate(network)
    ucinds = intersect(inds(t), uncontract_inds)
    if length(ucinds) == 0
      continue
    end
    for ind in ucinds
      push!(grouped_uncontracted_inds, [ind])
      edge_dict[[ind]] = (i, MAX_WEIGHT)
    end
  end
  split_inds_list = []
  for i in 1:length(grouped_uncontracted_inds)
    for j in (i + 1):length(grouped_uncontracted_inds)
      push!(split_inds_list, [grouped_uncontracted_inds[i], grouped_uncontracted_inds[j]])
    end
  end
  return mincut_inds_binary_tree(
    graph, capacity_matrix, edge_dict, grouped_uncontracted_inds, split_inds_list
  )
end

function mincut_inds_binary_tree(
  graph::Graphs.DiGraph,
  capacity_matrix::Matrix,
  edge_dict::Dict,
  uncontract_inds::Vector,
  split_inds_list::Vector,
)
  # base case here
  if length(uncontract_inds) <= 2
    return uncontract_inds
  end
  mincuts = [
    mincut_value(graph, capacity_matrix, edge_dict, uncontract_inds, split_inds) for
    split_inds in split_inds_list
  ]
  minval, i = findmin(mincuts)
  new_edge = split_inds_list[i]
  # update the graph
  add_vertex!(graph)
  last_vertex = size(graph)[1]
  u1, w_u1 = edge_dict[new_edge[1]]
  u2, w_u2 = edge_dict[new_edge[2]]
  Graphs.add_edge!(graph, u1, last_vertex)
  Graphs.add_edge!(graph, u2, last_vertex)
  Graphs.add_edge!(graph, last_vertex, u1)
  Graphs.add_edge!(graph, last_vertex, u2)
  new_capacity_matrix = zeros(last_vertex, last_vertex)
  new_capacity_matrix[1:(last_vertex - 1), 1:(last_vertex - 1)] = capacity_matrix
  new_capacity_matrix[u1, last_vertex] = w_u1
  new_capacity_matrix[u2, last_vertex] = w_u2
  new_capacity_matrix[last_vertex, u1] = w_u1
  new_capacity_matrix[last_vertex, u2] = w_u2
  # update the dict
  edge_dict[new_edge[1]] = (u1, last_vertex, w_u1)
  edge_dict[new_edge[2]] = (u2, last_vertex, w_u2)
  edge_dict[new_edge] = (last_vertex, MAX_WEIGHT)
  # update uncontract_inds
  uncontract_inds = setdiff(uncontract_inds, new_edge)
  uncontract_inds = vcat(uncontract_inds, [new_edge])
  # update split_inds_list
  split_inds_list = []
  # for i in 1:length(uncontract_inds) - 1
  #     push!(split_inds_list, [uncontract_inds[i], new_edge])
  # end
  for i in 1:length(uncontract_inds)
    for j in (i + 1):length(uncontract_inds)
      push!(split_inds_list, [uncontract_inds[i], uncontract_inds[j]])
    end
  end
  return mincut_inds_binary_tree(
    graph, new_capacity_matrix, edge_dict, uncontract_inds, split_inds_list
  )
end

function mincut_value(
  graph::Graphs.DiGraph,
  capacity_matrix::Matrix,
  edge_dict::Dict,
  uncontract_inds::Vector,
  split_inds::Vector,
)
  graph = copy(graph)
  # add two vertices to the graph to model the s and t
  add_vertices!(graph, 2)
  t = size(graph)[1]
  s = t - 1
  new_capacity_matrix = zeros(t, t)
  new_capacity_matrix[1:(t - 2), 1:(t - 2)] = capacity_matrix
  for ind in split_inds
    u, _ = edge_dict[ind]
    Graphs.add_edge!(graph, u, s)
    Graphs.add_edge!(graph, s, u)
    new_capacity_matrix[u, s] = MAX_WEIGHT
    new_capacity_matrix[s, u] = MAX_WEIGHT
  end
  terminal_inds = setdiff(uncontract_inds, split_inds)
  for ind in terminal_inds
    u, _ = edge_dict[ind]
    Graphs.add_edge!(graph, u, t)
    Graphs.add_edge!(graph, t, u)
    new_capacity_matrix[u, t] = MAX_WEIGHT
    new_capacity_matrix[t, u] = MAX_WEIGHT
  end
  _, _, flow = GraphsFlows.mincut(graph, s, t, new_capacity_matrix, EdmondsKarpAlgorithm())
  return flow
end
