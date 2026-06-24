import 'package:flutter/material.dart';

/// Category model for course catalog
class CourseCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final List<SubCategory> subCategories;

  const CourseCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.subCategories,
  });
}

/// Subcategory within a category
class SubCategory {
  final String id;
  final String name;
  final String description;
  final String promptHint;

  const SubCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.promptHint,
  });
}

/// All premade course categories
class CatalogData {
  static const List<CourseCategory> categories = [
    // ─── Tech & Programming ────────────────────
    CourseCategory(
      id: 'tech',
      name: 'Tech & Programming',
      icon: Icons.code_rounded,
      color: Color(0xFF6D5BDB),
      subCategories: [
        SubCategory(
          id: 'mobile_dev',
          name: 'Mobile App Development',
          description: 'Build iOS & Android apps with Flutter, React Native, and Swift',
          promptHint: 'Complete mobile app development course covering Flutter, React Native, and native development',
        ),
        SubCategory(
          id: 'fullstack',
          name: 'Full-Stack Development',
          description: 'Master frontend, backend, databases and deployment',
          promptHint: 'Full-stack web development course covering HTML, CSS, JavaScript, React, Node.js, and databases',
        ),
        SubCategory(
          id: 'ai_ml',
          name: 'AI & Machine Learning',
          description: 'Neural networks, deep learning, and practical ML projects',
          promptHint: 'Artificial intelligence and machine learning course with Python, TensorFlow, and real projects',
        ),
        SubCategory(
          id: 'data_science',
          name: 'Data Science',
          description: 'Python, pandas, visualization, and statistical analysis',
          promptHint: 'Data science course with Python, pandas, matplotlib, and statistical analysis',
        ),
        SubCategory(
          id: 'devops',
          name: 'DevOps & Cloud',
          description: 'Docker, Kubernetes, CI/CD, AWS, and cloud infrastructure',
          promptHint: 'DevOps engineering course covering Docker, Kubernetes, CI/CD pipelines, and AWS cloud',
        ),
        SubCategory(
          id: 'cybersecurity',
          name: 'Cybersecurity',
          description: 'Network security, ethical hacking, and penetration testing',
          promptHint: 'Cybersecurity and ethical hacking course covering network security and penetration testing',
        ),
        SubCategory(
          id: 'web3_blockchain',
          name: 'Web3 & Blockchain',
          description: 'Smart contracts, Solidity, DeFi, and decentralized apps',
          promptHint: 'Web3 and blockchain development course with Solidity smart contracts and DeFi',
        ),
        SubCategory(
          id: 'game_dev',
          name: 'Game Development',
          description: 'Unity, Unreal Engine, and game design fundamentals',
          promptHint: 'Game development course covering Unity, Unreal Engine, and game design principles',
        ),
      ],
    ),

    // ─── Languages ────────────────────────────
    CourseCategory(
      id: 'languages',
      name: 'Languages',
      icon: Icons.translate_rounded,
      color: Color(0xFF0DBAB5),
      subCategories: [
        SubCategory(id: 'english', name: 'English', description: 'Speaking, grammar, vocabulary & IELTS prep', promptHint: 'Complete English language course with grammar, speaking practice, vocabulary building, and IELTS preparation'),
        SubCategory(id: 'spanish', name: 'Spanish', description: 'Conversational Spanish from beginner to fluent', promptHint: 'Spanish language course from beginner to conversational fluency'),
        SubCategory(id: 'french', name: 'French', description: 'Learn French for travel, work, and culture', promptHint: 'French language course for beginners to intermediate level'),
        SubCategory(id: 'japanese', name: 'Japanese', description: 'Hiragana, Katakana, Kanji & conversation', promptHint: 'Japanese language course covering Hiragana, Katakana, basic Kanji, and conversational Japanese'),
        SubCategory(id: 'korean', name: 'Korean', description: 'Hangul, grammar patterns & K-culture', promptHint: 'Korean language course covering Hangul, grammar patterns, and Korean culture'),
        SubCategory(id: 'german', name: 'German', description: 'German for beginners to B2 level', promptHint: 'German language course from A1 to B2 level'),
        SubCategory(id: 'hindi', name: 'Hindi', description: 'Devanagari script, grammar & conversation', promptHint: 'Hindi language course with Devanagari script reading and conversational Hindi'),
        SubCategory(id: 'mandarin', name: 'Mandarin Chinese', description: 'Pinyin, tones, characters & conversation', promptHint: 'Mandarin Chinese course covering Pinyin, tones, basic characters, and conversation'),
      ],
    ),

    // ─── Design ──────────────────────────────
    CourseCategory(
      id: 'design',
      name: 'Design',
      icon: Icons.palette_rounded,
      color: Color(0xFFE879F9),
      subCategories: [
        SubCategory(id: 'ui_ux', name: 'UI/UX Design', description: 'Figma, design systems, user research & prototyping', promptHint: 'UI/UX design course covering Figma, design systems, user research, and prototyping'),
        SubCategory(id: 'graphic_design', name: 'Graphic Design', description: 'Adobe Creative Suite, branding & visual identity', promptHint: 'Graphic design course with Adobe Photoshop, Illustrator, and branding'),
        SubCategory(id: 'motion_graphics', name: 'Motion Graphics', description: 'After Effects, animation, and video effects', promptHint: 'Motion graphics and animation course using After Effects'),
        SubCategory(id: '3d_design', name: '3D Design & Modeling', description: 'Blender, 3D modeling, texturing & rendering', promptHint: '3D design and modeling course using Blender'),
      ],
    ),

    // ─── Business ────────────────────────────
    CourseCategory(
      id: 'business',
      name: 'Business',
      icon: Icons.business_center_rounded,
      color: Color(0xFFF59E0B),
      subCategories: [
        SubCategory(id: 'digital_marketing', name: 'Digital Marketing', description: 'SEO, social media, ads & content strategy', promptHint: 'Digital marketing course covering SEO, social media marketing, Google Ads, and content strategy'),
        SubCategory(id: 'finance', name: 'Finance & Investing', description: 'Stock market, crypto, personal finance & budgeting', promptHint: 'Finance and investing course covering stock market, cryptocurrency, and personal finance'),
        SubCategory(id: 'entrepreneurship', name: 'Entrepreneurship', description: 'Startup strategy, fundraising & business planning', promptHint: 'Entrepreneurship course covering startup strategy, business planning, and fundraising'),
        SubCategory(id: 'product_mgmt', name: 'Product Management', description: 'Product strategy, roadmaps & agile methodology', promptHint: 'Product management course covering product strategy, roadmaps, and agile methodology'),
      ],
    ),

    // ─── Science ─────────────────────────────
    CourseCategory(
      id: 'science',
      name: 'Science',
      icon: Icons.science_rounded,
      color: Color(0xFF3B82F6),
      subCategories: [
        SubCategory(id: 'physics', name: 'Physics', description: 'Classical mechanics, quantum physics & astrophysics', promptHint: 'Physics course covering classical mechanics, quantum mechanics, and astrophysics'),
        SubCategory(id: 'mathematics', name: 'Mathematics', description: 'Calculus, linear algebra, statistics & discrete math', promptHint: 'Mathematics course covering calculus, linear algebra, statistics, and discrete mathematics'),
        SubCategory(id: 'biology', name: 'Biology', description: 'Cell biology, genetics, evolution & anatomy', promptHint: 'Biology course covering cell biology, genetics, evolution, and human anatomy'),
        SubCategory(id: 'chemistry', name: 'Chemistry', description: 'Organic, inorganic & physical chemistry', promptHint: 'Chemistry course covering organic, inorganic, and physical chemistry'),
      ],
    ),

    // ─── Creative ────────────────────────────
    CourseCategory(
      id: 'creative',
      name: 'Creative',
      icon: Icons.brush_rounded,
      color: Color(0xFFEF4444),
      subCategories: [
        SubCategory(id: 'music', name: 'Music Production', description: 'DAW, mixing, mastering & music theory', promptHint: 'Music production course covering DAW, mixing, mastering, and music theory'),
        SubCategory(id: 'photography', name: 'Photography', description: 'Camera settings, composition & Lightroom editing', promptHint: 'Photography course covering camera settings, composition, and Lightroom editing'),
        SubCategory(id: 'video_editing', name: 'Video Editing', description: 'Premiere Pro, DaVinci Resolve & storytelling', promptHint: 'Video editing course covering Premiere Pro, DaVinci Resolve, and visual storytelling'),
        SubCategory(id: 'writing', name: 'Creative Writing', description: 'Fiction, non-fiction, blogging & copywriting', promptHint: 'Creative writing course covering fiction, blogging, and copywriting'),
      ],
    ),
  ];
}
