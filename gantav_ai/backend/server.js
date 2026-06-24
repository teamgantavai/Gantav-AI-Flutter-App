const express = require('express');
const cors = require('cors');
const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// ─────────────────────────────────────────────────────────────────────────────
// Mock Data
// ─────────────────────────────────────────────────────────────────────────────

const mockUser = {
  id: 'user_001',
  name: 'Rahul Sharma',
  handle: 'rahulsharma',
  email: 'rahul@example.com',
  gantav_score: 1250,
  streak_days: 7,
  lessons_completed: 34,
  quizzes_passed: 28,
  week_activity: [true, true, true, true, true, false, true],
};

const mockCourses = [
  {
    id: 'course_001',
    title: 'Python for Machine Learning',
    description: 'Master Python fundamentals and essential libraries like NumPy, Pandas, and Scikit-learn.',
    category: 'Machine Learning',
    thumbnail_url: 'https://img.youtube.com/vi/7eh4d6sabA0/maxresdefault.jpg',
    rating: 4.8,
    learner_count: 2841,
    total_lessons: 24,
    completed_lessons: 14,
    estimated_time: '8 weeks',
    skills: ['Python', 'NumPy', 'Pandas', 'Scikit-learn'],
    modules: [],
  },
  {
    id: 'course_002',
    title: 'Full-Stack Web Development',
    description: 'Build modern web applications with React, Node.js, and PostgreSQL.',
    category: 'Web Development',
    thumbnail_url: 'https://img.youtube.com/vi/nu_pCVPKzTk/maxresdefault.jpg',
    rating: 4.7,
    learner_count: 3567,
    total_lessons: 30,
    completed_lessons: 8,
    estimated_time: '10 weeks',
    skills: ['React', 'Node.js', 'PostgreSQL', 'TypeScript'],
    modules: [],
  },
  {
    id: 'course_003',
    title: 'Data Structures & Algorithms',
    description: 'Master DSA concepts with visual explanations and coding practice.',
    category: 'Computer Science',
    thumbnail_url: 'https://img.youtube.com/vi/8hly31xKli0/maxresdefault.jpg',
    rating: 4.9,
    learner_count: 5120,
    total_lessons: 36,
    completed_lessons: 0,
    estimated_time: '12 weeks',
    skills: ['Arrays', 'Trees', 'Graphs', 'Dynamic Programming'],
    modules: [],
  },
];

const mockPulse = [
  { id: 'pulse_001', user_name: 'Priya', action: 'completed', course_name: 'Python Basics', time_ago: '2m ago' },
  { id: 'pulse_002', user_name: 'Arjun', action: 'started', course_name: 'ML Fundamentals', time_ago: '5m ago' },
  { id: 'pulse_003', user_name: 'Sneha', action: 'scored 95% on', course_name: 'Data Visualization Quiz', time_ago: '8m ago' },
  { id: 'pulse_004', user_name: 'Vikram', action: 'hit a 14-day streak in', course_name: 'Web Development', time_ago: '12m ago' },
  { id: 'pulse_005', user_name: 'Ananya', action: 'enrolled in', course_name: 'Flutter App Development', time_ago: '15m ago' },
];

const mockQuiz = [
  {
    id: 'q_001',
    question: 'What is the output of print(type(42)) in Python?',
    options: ["<class 'int'>", "<class 'float'>", "<class 'str'>", "<class 'number'>"],
    correct_index: 0,
    explanation: 'In Python, integers are of type int. The type() function returns the class of the object.',
  },
  {
    id: 'q_002',
    question: 'Which NumPy function creates an array of evenly spaced values?',
    options: ['np.zeros()', 'np.linspace()', 'np.random()', 'np.full()'],
    correct_index: 1,
    explanation: 'np.linspace() creates an array of evenly spaced values over a specified interval.',
  },
  {
    id: 'q_003',
    question: 'What does the Pandas .describe() method return?',
    options: ['Column names', 'Data types of each column', 'Summary statistics of numerical columns', 'Number of null values'],
    correct_index: 2,
    explanation: '.describe() generates descriptive statistics including count, mean, std, min, max, and quartiles.',
  },
];

// ─────────────────────────────────────────────────────────────────────────────
// Routes
// ─────────────────────────────────────────────────────────────────────────────

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Get user profile
app.get('/api/users/:userId', (req, res) => {
  res.json(mockUser);
});

// Get user's courses with progress
app.get('/api/users/:userId/courses', (req, res) => {
  res.json(mockCourses);
});

// Browse all courses
app.get('/api/courses', (req, res) => {
  res.json(mockCourses);
});

// Enroll in a course
app.post('/api/courses/:courseId/enroll', (req, res) => {
  res.json({ success: true, message: 'Enrolled successfully' });
});

// Mark lesson complete
app.post('/api/courses/:courseId/lessons/:lessonId/complete', (req, res) => {
  res.json({ success: true, message: 'Lesson marked as complete' });
});

// Get quiz for a lesson
app.get('/api/courses/:courseId/lessons/:lessonId/quiz', (req, res) => {
  res.json(mockQuiz);
});

// Social pulse events
app.get('/api/pulse/:userId', (req, res) => {
  res.json(mockPulse);
});

// AI suggest path (mock)
app.post('/api/ai/suggest-path', (req, res) => {
  const { dream } = req.body;
  res.json({
    dream: dream,
    suggested_path: {
      title: `Path to: ${dream}`,
      courses: mockCourses.slice(0, 2),
      estimated_duration: '6 months',
    },
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Start Server
// ─────────────────────────────────────────────────────────────────────────────

app.listen(PORT, () => {
  console.log(`🚀 Gantav AI Backend running on port ${PORT}`);
  console.log(`   Health: http://localhost:${PORT}/health`);
});
