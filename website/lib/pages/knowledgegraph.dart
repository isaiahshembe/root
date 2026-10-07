import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;

class Knowledgegraph extends StatefulWidget {
  const Knowledgegraph({super.key});

  @override
  State<Knowledgegraph> createState() => _KnowledgegraphState();
}

class _KnowledgegraphState extends State<Knowledgegraph>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  String? _selectedNode;
  String? _selectedEdge;

  // Real data from Supabase
  List<GraphNode> _nodes = [];
  List<GraphEdge> _edges = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  // Statistics
  int _totalArtifacts = 0;
  int _totalHeritageSites = 0;
  int _totalRelationships = 0;

  // Graph dimensions
  double _graphWidth = 1000;
  double _graphHeight = 800;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _loadGraphData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadGraphData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final supabase = Supabase.instance.client;

      // Fetch heritage sites
      final heritageSites = await supabase
          .from('heritage_sites')
          .select('id, name, description');

      // Fetch artifacts with their associated heritage sites
      final artifacts = await supabase
          .from('artifacts')
          .select(
            'id, heritage_site_id, cultural_narrative, plant_image_url, submitted_at',
          );

      setState(() {
        _totalHeritageSites = heritageSites.length;
        _totalArtifacts = artifacts.length;

        // Clear existing nodes and edges
        _nodes = [];
        _edges = [];

        // Calculate dynamic dimensions based on data count
        final int totalNodes = heritageSites.length + artifacts.length;
        _graphHeight = math.max(800, 400 + (totalNodes * 30));
        _graphWidth = math.max(1000, 600 + (totalNodes * 20));

        // Create nodes from heritage sites (Botanical nodes)
        final int siteCount = heritageSites.length;
        for (int i = 0; i < siteCount; i++) {
          final site = heritageSites[i];
          // Position in a circle layout - use dynamic radius based on count
          final radius = 200.0;
          final angle = (2 * math.pi * i) / math.max(siteCount, 1);
          final x = _graphWidth / 2 + radius * math.cos(angle);
          final y = 200 + radius * math.sin(angle);

          _nodes.add(
            GraphNode(
              id: site['id'],
              name: site['name'],
              type: NodeType.botanical,
              x: x,
              y: y,
              description: site['description'] ?? 'Heritage site in Uganda',
              artifactCount: 0,
            ),
          );
        }

        // Create nodes from artifacts (Artifact nodes)
        final int artifactCount = artifacts.length;
        for (int i = 0; i < artifactCount; i++) {
          final artifact = artifacts[i];
          // Position in a lower circle layout
          final radius = 200.0;
          final angle = (2 * math.pi * i) / math.max(artifactCount, 1);
          final x = _graphWidth / 2 + radius * math.cos(angle);
          final y = 500 + radius * math.sin(angle);

          // Create a short ID for display
          String shortName =
              'Artifact ${artifact['id'].toString().substring(0, math.min(8, artifact['id'].toString().length))}';

          _nodes.add(
            GraphNode(
              id: artifact['id'],
              name: shortName,
              type: NodeType.artifact,
              x: x,
              y: y,
              description: artifact['cultural_narrative'] != null
                  ? (artifact['cultural_narrative'].length > 100
                        ? '${artifact['cultural_narrative'].substring(0, 100)}...'
                        : artifact['cultural_narrative'])
                  : 'Cultural artifact with traditional knowledge',
              artifactCount: 0,
            ),
          );

          // Create edges between artifact and its heritage site
          if (artifact['heritage_site_id'] != null) {
            _edges.add(
              GraphEdge(
                id: '${artifact['id']}_${artifact['heritage_site_id']}',
                source: artifact['heritage_site_id'],
                target: artifact['id'],
                label: 'collected_at',
                description:
                    'This artifact was collected at this heritage site',
              ),
            );
          }
        }

        // Update artifact counts for heritage sites
        for (var site in _nodes.where((n) => n.type == NodeType.botanical)) {
          final artifactCountForSite = _edges
              .where((e) => e.source == site.id)
              .length;
          site.artifactCount = artifactCountForSite;
        }

        // Create additional semantic edges between heritage sites that have artifacts
        final heritageSitesWithArtifacts = _nodes
            .where((n) => n.type == NodeType.botanical && n.artifactCount > 0)
            .toList();

        for (int i = 0; i < heritageSitesWithArtifacts.length; i++) {
          for (int j = i + 1; j < heritageSitesWithArtifacts.length; j++) {
            _edges.add(
              GraphEdge(
                id: '${heritageSitesWithArtifacts[i].id}_${heritageSitesWithArtifacts[j].id}',
                source: heritageSitesWithArtifacts[i].id,
                target: heritageSitesWithArtifacts[j].id,
                label: 'related_region',
                description:
                    'These heritage sites share similar botanical diversity and cultural significance',
              ),
            );
          }
        }

        _totalRelationships = _edges.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 900;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: isMobile
                ? Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildGraphVisualization(isMobile),
                      const SizedBox(height: 24),
                      _buildSidePanel(),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildGraphVisualization(isMobile),
                      ),
                      const SizedBox(width: 24),
                      Expanded(flex: 1, child: _buildSidePanel()),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade50, Colors.green.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ontology-Driven Multimodal Knowledge Graph',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Interactive visualization of the semantic relationships between botanical nodes, artifact nodes, and cultural narrative edges. Click on nodes and edges to explore provenance and cultural context.',
                    style: TextStyle(color: Colors.green.shade700, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphVisualization(bool isMobile) {
    if (_isLoading) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                CircularProgressIndicator(color: Colors.green.shade600),
                const SizedBox(height: 16),
                Text(
                  'Loading knowledge graph data...',
                  style: TextStyle(color: Colors.green.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_hasError) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'Error loading graph data',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadGraphData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_nodes.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.insights, size: 48, color: Colors.green.shade400),
                const SizedBox(height: 16),
                Text(
                  'No data yet',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Submit artifacts through the Crowdsource page to build your knowledge graph!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.share, color: Colors.green.shade700, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Knowledge Graph Visualization',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.zoom_in,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Pinch to zoom | Drag to pan',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: isMobile ? 500 : 600,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green.shade200),
                borderRadius: BorderRadius.circular(12),
                color: Colors.green.shade50,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  minScale: 0.3,
                  maxScale: 3.0,
                  boundaryMargin: const EdgeInsets.all(50),
                  constrained: false,
                  child: SizedBox(
                    width: _graphWidth,
                    height: _graphHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Draw edges
                        ..._buildEdges(),
                        // Draw nodes
                        ..._buildNodes(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Scroll or pinch to zoom. Drag to pan and explore the graph.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildEdges() {
    final List<Widget> edgeWidgets = [];

    for (var edge in _edges) {
      final sourceNode = _nodes.firstWhere((n) => n.id == edge.source);
      final targetNode = _nodes.firstWhere((n) => n.id == edge.target);

      edgeWidgets.add(
        Positioned(
          left: 0,
          top: 0,
          child: CustomPaint(
            painter: EdgePainter(
              start: Offset(sourceNode.x, sourceNode.y),
              end: Offset(targetNode.x, targetNode.y),
              label: edge.label,
              isSelected: _selectedEdge == edge.id,
              animation: _animationController,
            ),
            size: Size(_graphWidth, _graphHeight),
          ),
        ),
      );
    }

    return edgeWidgets;
  }

  List<Widget> _buildNodes() {
    final List<Widget> nodeWidgets = [];

    for (var node in _nodes) {
      nodeWidgets.add(
        Positioned(
          left: node.x - 40,
          top: node.y - 40,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedNode = _selectedNode == node.id ? null : node.id;
                _selectedEdge = null;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getNodeColor(
                  node.type,
                ).withOpacity(_selectedNode == node.id ? 1.0 : 0.9),
                border: Border.all(
                  color: Colors.white,
                  width: _selectedNode == node.id ? 4 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_getNodeIcon(node.type), color: Colors.white, size: 30),
                  const SizedBox(height: 4),
                  Text(
                    node.name.length > 12
                        ? '${node.name.substring(0, 10)}...'
                        : node.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (node.type == NodeType.botanical && node.artifactCount > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${node.artifactCount}',
                        style: TextStyle(
                          fontSize: 8,
                          color: _getNodeColor(node.type),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return nodeWidgets;
  }

  Color _getNodeColor(NodeType type) {
    switch (type) {
      case NodeType.botanical:
        return Colors.green.shade600;
      case NodeType.artifact:
        return Colors.orange.shade600;
    }
  }

  IconData _getNodeIcon(NodeType type) {
    switch (type) {
      case NodeType.botanical:
        return Icons.forest;
      case NodeType.artifact:
        return Icons.photo_camera;
    }
  }

  Widget _buildSidePanel() {
    return Column(
      children: [
        // Schema Section
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.schema, color: Colors.green.shade700, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'Knowledge Graph Schema',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSchemaItem(
                  Icons.forest,
                  'Botanical Nodes',
                  'Heritage sites, plant species, and botanical specimens',
                  Colors.green,
                ),
                const SizedBox(height: 16),
                _buildSchemaItem(
                  Icons.photo_camera,
                  'Artifact Nodes',
                  'Crowdsourced images, cultural narratives, provenance metadata',
                  Colors.orange,
                ),
                const SizedBox(height: 16),
                _buildSchemaItem(
                  Icons.share,
                  'Cultural Edges',
                  'Semantic relationships: "collected_at", "related_region"',
                  Colors.purple,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Statistics Section
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.show_chart,
                      color: Colors.green.shade700,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Graph Statistics',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '${_totalHeritageSites}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              ),
                              Text(
                                'Heritage Sites',
                                style: TextStyle(
                                  color: Colors.green.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.green.shade200,
                          ),
                          Column(
                            children: [
                              Text(
                                '${_totalArtifacts}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                              Text(
                                'Artifacts',
                                style: TextStyle(
                                  color: Colors.green.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.green.shade200,
                          ),
                          Column(
                            children: [
                              Text(
                                '${_totalRelationships}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade800,
                                ),
                              ),
                              Text(
                                'Relationships',
                                style: TextStyle(
                                  color: Colors.green.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Each artifact is connected to its heritage site through "collected_at" relationships. Heritage sites with artifacts are also connected through "related_region" relationships.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Selected Info Section
        if (_selectedNode != null || _selectedEdge != null)
          const SizedBox(height: 24),
        if (_selectedNode != null) _buildSelectedInfo(),
        if (_selectedEdge != null) _buildSelectedEdgeInfo(),
      ],
    );
  }

  Widget _buildSchemaItem(
    IconData icon,
    String title,
    String description,
    MaterialColor color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 24, color: color.shade700),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color.shade800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedInfo() {
    final node = _nodes.firstWhere((n) => n.id == _selectedNode);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  'Selected ${node.type == NodeType.botanical ? 'Heritage Site' : 'Artifact'}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getNodeColor(node.type).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getNodeIcon(node.type),
                    color: _getNodeColor(node.type),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        node.type == NodeType.botanical
                            ? 'Heritage Site in Uganda'
                            : 'Cultural Artifact',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                node.description,
                style: TextStyle(fontSize: 12, color: Colors.green.shade700),
              ),
            ),
            if (node.type == NodeType.botanical && node.artifactCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.photo_library,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${node.artifactCount} artifact${node.artifactCount != 1 ? 's' : ''} collected here',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedEdgeInfo() {
    final edge = _edges.firstWhere((e) => e.id == _selectedEdge);
    final sourceNode = _nodes.firstWhere((n) => n.id == edge.source);
    final targetNode = _nodes.firstWhere((n) => n.id == edge.target);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.share, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  'Selected Relationship',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          sourceNode.name,
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Icon(Icons.arrow_forward, color: Colors.purple.shade700),
                      Expanded(
                        child: Text(
                          targetNode.name,
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      edge.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              edge.description,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

enum NodeType { botanical, artifact }

class GraphNode {
  final String id;
  String name;
  final NodeType type;
  final double x;
  final double y;
  String description;
  int artifactCount;

  GraphNode({
    required this.id,
    required this.name,
    required this.type,
    required this.x,
    required this.y,
    required this.description,
    required this.artifactCount,
  });
}

class GraphEdge {
  final String id;
  final String source;
  final String target;
  final String label;
  final String description;

  GraphEdge({
    required this.id,
    required this.source,
    required this.target,
    required this.label,
    required this.description,
  });
}

class EdgePainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final String label;
  final bool isSelected;
  final Animation<double> animation;

  EdgePainter({
    required this.start,
    required this.end,
    required this.label,
    required this.isSelected,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isSelected ? Colors.purple.shade700 : Colors.green.shade300
      ..strokeWidth = isSelected ? 3.0 : 2.0
      ..style = PaintingStyle.stroke;

    // Draw line
    final path = Path();
    path.moveTo(start.dx, start.dy);
    path.lineTo(end.dx, end.dy);
    canvas.drawPath(path, paint);

    // Draw animated dots for selected edges
    if (isSelected) {
      final dotPaint = Paint()
        ..color = Colors.purple.shade700
        ..style = PaintingStyle.fill;

      final t = animation.value;
      final dotX = start.dx + (end.dx - start.dx) * t;
      final dotY = start.dy + (end.dy - start.dy) * t;
      canvas.drawCircle(Offset(dotX, dotY), 4, dotPaint);
    }

    // Draw label
    final midPoint = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: isSelected ? Colors.purple.shade700 : Colors.green.shade600,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final labelRect = Rect.fromLTWH(
      midPoint.dx - textPainter.width / 2 - 4,
      midPoint.dy - 20 - 4,
      textPainter.width + 8,
      textPainter.height + 8,
    );

    final backgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawRect(labelRect, backgroundPaint);

    textPainter.paint(
      canvas,
      Offset(midPoint.dx - textPainter.width / 2, midPoint.dy - 20),
    );
  }

  @override
  bool shouldRepaint(covariant EdgePainter oldDelegate) {
    return oldDelegate.isSelected != isSelected ||
        oldDelegate.animation.value != animation.value;
  }
}
