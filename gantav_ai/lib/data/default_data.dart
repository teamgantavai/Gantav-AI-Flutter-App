import '../models/models.dart';

class DefaultData {
  static List<Course> get initialSuggestions => [
    Course(
      id: 'default_python',
      title: 'Master Python Programming 2024',
      description: 'Learn Python from scratch with real-world projects and AI assistance.',
      category: 'Programming',
      thumbnailUrl: '', // Will use fallback
      rating: 4.9,
      learnerCount: 1240,
      totalLessons: 12,
      estimatedTime: '6h 30m',
      skills: ['Python', 'Logic', 'Backend'],
      modules: [], // No modules yet, clicking will trigger generation
    ),
    Course(
      id: 'default_web',
      title: 'Full-Stack Web Development',
      description: 'The complete guide to building modern websites with HTML, CSS, and JS.',
      category: 'Web Development',
      thumbnailUrl: '',
      rating: 4.8,
      learnerCount: 2150,
      totalLessons: 15,
      estimatedTime: '10h 20m',
      skills: ['HTML', 'CSS', 'JavaScript'],
      modules: [],
    ),
    Course(
      id: 'default_ai',
      title: 'AI & Prompt Engineering',
      description: 'Unlock the power of LLMs and learn how to build AI-powered apps.',
      category: 'Artificial Intelligence',
      thumbnailUrl: '',
      rating: 4.9,
      learnerCount: 3200,
      totalLessons: 8,
      estimatedTime: '4h 45m',
      skills: ['AI', 'Prompts', 'Gemini'],
      modules: [],
    ),
    Course(
      id: 'default_design',
      title: 'Modern UI/UX Design Masterclass',
      description: 'Design beautiful, user-centric interfaces using industry standards.',
      category: 'Design',
      thumbnailUrl: '',
      rating: 4.7,
      learnerCount: 1850,
      totalLessons: 10,
      estimatedTime: '5h 15m',
      skills: ['Figma', 'UI', 'UX'],
      modules: [],
    ),
  ];
}
