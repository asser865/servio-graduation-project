import json
from networkx.readwrite import json_graph
from pathlib import Path

data = json.loads(Path('graphify-out/graph.json').read_text())
G = json_graph.node_link_graph(data, edges='links')

print(f"Graph: {G.number_of_nodes()} nodes, {G.number_of_edges()} edges")
print()

queries = {
    'booking_details_screen': ['booking', 'details', 'screen', 'navigation'],
    'contact_submit_backend': ['contact', 'submit', 'support', 'ticket', 'issue'],
    'dispute_booking_link': ['dispute', 'booking', 'link', 'bookingId'],
}

for qname, terms in queries.items():
    print(f"=== {qname} ===")
    scored = []
    for nid, ndata in G.nodes(data=True):
        label = ndata.get('label', '').lower()
        src = ndata.get('source_file', '').lower()
        score = sum(1 for t in terms if t in label or t in src)
        if score >= 2:
            scored.append((score, nid, ndata.get('label',''), src))
    scored.sort(reverse=True)
    for score, nid, label, src in scored[:12]:
        edges_out = [(G.edges[nid, nb].get('relation','?'), G.nodes[nb].get('label',''), G.nodes[nb].get('source_file',''))
                     for nb in G.neighbors(nid) if G.has_edge(nid, nb)]
        print(f"  [{label}] src={src} (score={score})")
        for rel, nb_label, nb_src in edges_out[:5]:
            print(f"    --> {rel} --> {nb_label} ({nb_src})")
    print()
