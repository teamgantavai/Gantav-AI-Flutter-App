import 'package:flutter/material.dart';

/// Seekho-style attractive course cards shown in the Home "Trending Now"
/// section and the Explore Categories grid. Each card is a ready-to-generate
/// course: tapping it runs the same course generation pipeline as a
/// subcategory, using the composed prompt as the topic.
///
/// ### 12D.5 — Language toggle
/// Each card now exposes a [defaultLang] ('en' or 'hi'). The UI renders a
/// flag toggle so users can flip between English and Hindi content per card.
/// The chosen lang is forwarded as the YouTube `relevanceLanguage` parameter.
///
/// ### Variation on repeat taps
/// [angles] lists distinct sub-focuses within the same category. The
/// AppState rotates through these on every tap so the same card never
/// generates the same course twice in a row.
class TrendingCourse {
  final String id;
  final String title;
  final String tagline;       // one-line value prop shown on the card
  final String promptHint;   // base prompt — always used as the spine
  final List<String> angles; // rotating sub-focuses for variation on retaps
  final IconData icon;
  final Color primary;       // gradient start
  final Color secondary;     // gradient end
  final String badge;        // e.g. "Trending", "Hot", "New"
  /// 12D.5 — default content language for this card ('en' | 'hi')
  final String defaultLang;

  const TrendingCourse({
    required this.id,
    required this.title,
    required this.tagline,
    required this.promptHint,
    required this.angles,
    required this.icon,
    required this.primary,
    required this.secondary,
    this.badge = 'Trending',
    this.defaultLang = 'en',
  });
}

class TrendingData {
  /// Curated high-intent topics that map to real Indian student / young-adult
  /// aspirations. Keep this list short and conversion-optimised.
  ///
  /// The 3 "modern dev" cards up top (Vibe Coding, AI Agents, Build AI Apps)
  /// intentionally lead the list so 2026-era learners see cutting-edge topics
  /// before the older evergreens.
  static const List<TrendingCourse> courses = [
    TrendingCourse(
      id: 't_vibe_coding',
      title: 'Vibe coding with AI',
      tagline: 'Ship real apps with Claude Code, Cursor & v0 — no boilerplate',
      promptHint:
          'Complete 2026 course on vibe coding and AI-assisted development — using Claude Code, Cursor, Windsurf, v0.dev, and GitHub Copilot to build full apps by conversation, including prompt patterns, agentic workflows, and shipping production code as a solo dev',
      angles: [
        'Claude Code mastery — project setup, subagents, hooks, slash commands, MCP servers, shipping features end-to-end',
        'Cursor + Windsurf workflow for solo founders — tab completion, composer, rules files, multi-file editing',
        'v0 and Lovable for rapid UI — generating full Next.js apps from prompts, iterating visually, exporting clean code',
        'Vibe coding mental model — breaking work into agent-sized tasks, writing CLAUDE.md / .cursorrules, verifying AI output',
        'Shipping an AI-coded SaaS in a weekend — auth, database, deploy to Vercel/Supabase, payments, everything with AI',
        'Agentic coding patterns in 2026 — when to let the AI drive vs step in, TDD with AI, reviewing agent PRs',
      ],
      icon: Icons.auto_fix_high_rounded,
      primary: Color(0xFF8B5CF6),
      secondary: Color(0xFF06B6D4),
      badge: 'New',
    ),
    TrendingCourse(
      id: 't_ai_agents',
      title: 'Build AI agents & MCP',
      tagline: 'LangGraph, agent loops, tool use & Model Context Protocol',
      promptHint:
          'Complete 2026 course on building AI agents and MCP servers — agent architectures (ReAct, plan-execute, multi-agent), tool calling, LangGraph, CrewAI, AutoGen, building Model Context Protocol (MCP) servers for Claude and other LLM hosts, memory, evals, and shipping agents to production',
      angles: [
        'MCP server from scratch — protocol basics, exposing tools/resources/prompts, connecting to Claude Code and Cursor',
        'LangGraph deep-dive — state graphs, conditional edges, human-in-the-loop, checkpointing, streaming',
        'Agent architectures compared — ReAct, plan-and-execute, multi-agent orchestration, choosing the right pattern',
        'Tool use and function calling — designing tool schemas, error handling, retries, parallel tool calls',
        'Agent memory and RAG — vector stores (Pinecone, Chroma, Qdrant), hybrid search, context engineering',
        'Evals and observability for agents — LangSmith, trace inspection, regression tests, production monitoring',
      ],
      icon: Icons.hub_rounded,
      primary: Color(0xFF14B8A6),
      secondary: Color(0xFF6366F1),
      badge: 'Hot',
    ),
    TrendingCourse(
      id: 't_build_ai_app',
      title: 'Build & ship an AI app',
      tagline: 'LLM wrapper startups, RAG, evals & your first paying user',
      promptHint:
          'Complete 2026 course on building and shipping an AI-powered product — choosing the right LLM (Claude, GPT, Gemini, Llama), RAG pipelines, streaming UIs with Vercel AI SDK, prompt engineering in production, cost control, evals, and going from MVP to paying users',
      angles: [
        'AI SaaS MVP in a week — stack (Next.js + Vercel AI SDK + Supabase), streaming, auth, billing with Stripe',
        'RAG pipelines that actually work — chunking strategies, embeddings, reranking, hybrid search, citations',
        'Prompt engineering in production — versioning prompts, A/B testing, guardrails, structured outputs, JSON mode',
        'LLM cost control and caching — prompt caching, model routing (cheap→expensive), token budgets, rate limits',
        'Evals for AI products — LLM-as-judge, golden datasets, regression suites before every prompt change',
        'Distribution for AI indie hackers — Product Hunt, Twitter/X, cold outbound, SEO with programmatic pages',
      ],
      icon: Icons.rocket_launch_rounded,
      primary: Color(0xFFEC4899),
      secondary: Color(0xFFF59E0B),
      badge: 'Trending',
    ),
    TrendingCourse(
      id: 't_youtuber',
      title: 'How to become a YouTuber',
      tagline: 'Channel setup, content strategy, monetisation & first 1K subs',
      promptHint:
          'Complete course on becoming a successful YouTuber — channel setup, niche selection, video editing, SEO, thumbnails, monetisation, and growth strategy for Indian creators',
      angles: [
        'Zero-to-1000 subscribers playbook for brand new Indian YouTubers — niche picking, channel branding, first 10 videos',
        'YouTube SEO and thumbnail/title mastery — CTR optimisation, keyword research, TubeBuddy/VidIQ workflows',
        'Video editing for YouTubers — Premiere Pro / CapCut workflow, b-roll, pacing, retention editing',
        'YouTube monetisation deep-dive — AdSense, brand deals, sponsorships, affiliate, memberships, merch',
        'YouTube Shorts growth in 2026 — algorithm, hook writing, shooting on phone, converting Shorts viewers to long-form',
        'Faceless YouTube channels — niche ideas, AI tools, stock footage, voiceover, automation pipeline',
      ],
      icon: Icons.smart_display_rounded,
      primary: Color(0xFFEF4444),
      secondary: Color(0xFFEC4899),
      badge: 'Hot',
      defaultLang: 'hi',
    ),
    TrendingCourse(
      id: 't_earn_student',
      title: 'Earn money as a student',
      tagline: 'Freelancing, content, tutoring — realistic side-income paths',
      promptHint:
          'Complete course on how Indian students can earn money online — freelancing, content creation, affiliate marketing, online tutoring, and side-income skills that actually pay',
      angles: [
        'Freelance writing and content creation for Indian students — getting first clients, pricing, portfolio',
        'Online tutoring side-hustle — Chegg, Vedantu, personal tutoring, YouTube tutoring channel',
        'Affiliate marketing for students — Amazon, niche blogs, Telegram deal channels, Instagram affiliate pages',
        'Selling digital products as a student — Notion templates, Canva designs, ebooks, study notes',
        'Part-time remote jobs for college students in India — data entry, virtual assistant, customer support',
        'Reselling and dropshipping basics — Meesho, Shopify, product sourcing, Instagram marketing',
      ],
      icon: Icons.currency_rupee_rounded,
      primary: Color(0xFF10B981),
      secondary: Color(0xFF059669),
      badge: 'Trending',
      defaultLang: 'hi',
    ),
    TrendingCourse(
      id: 't_govt_id',
      title: 'Govt ID & documents guide',
      tagline: 'Aadhaar, PAN, Passport, voter card — step-by-step for 2026',
      promptHint:
          'Complete step-by-step guide to apply for Indian government IDs and documents — Aadhaar, PAN card, Passport, Voter ID, Driving Licence, and how to fix common errors',
      angles: [
        'Aadhaar deep-dive — new enrolment, updates, biometric lock, mAadhaar, common rejection reasons',
        'PAN card end-to-end — instant e-PAN, NSDL vs UTIITSL, linking with Aadhaar, corrections',
        'Indian passport application — Tatkal vs normal, documents, police verification, appointment booking',
        'Voter ID (EPIC) and voter registration — Form 6, online application, correction, download',
        'Driving Licence process — learner\'s licence, slot booking, test, RTO documents',
        'Ration card, income certificate, domicile — state portals, documents, common issues',
      ],
      icon: Icons.badge_rounded,
      primary: Color(0xFF6366F1),
      secondary: Color(0xFF8B5CF6),
      badge: 'Useful',
      defaultLang: 'hi',
    ),
    TrendingCourse(
      id: 't_freelancing',
      title: 'Freelancing from home',
      tagline: 'Fiverr, Upwork, cold emails & your first paying client',
      promptHint:
          'Complete freelancing course — how to start on Fiverr and Upwork, pick a skill, write proposals, handle clients, and earn in dollars from India',
      angles: [
        'Fiverr from zero — gig creation, SEO, pricing, first orders, level 1/2, pro tier',
        'Upwork winning formula — profile optimisation, proposals, Connects strategy, Rising Talent',
        'Cold email and LinkedIn outreach for freelancers — finding leads, templates, closing',
        'Freelance pricing, invoicing, and receiving international payments — Wise, Payoneer, tax basics',
        'Picking a freelance skill that actually pays in 2026 — high-demand niches, upskilling roadmap',
        'Scaling from freelancer to agency — SOPs, hiring, retainers, productised services',
      ],
      icon: Icons.laptop_mac_rounded,
      primary: Color(0xFF0EA5E9),
      secondary: Color(0xFF2563EB),
      badge: 'Trending',
    ),
    TrendingCourse(
      id: 't_instagram',
      title: 'Grow on Instagram in 2026',
      tagline: 'Reels, algorithm hacks, niches that actually blow up',
      promptHint:
          'Complete Instagram growth course for 2026 — reels strategy, algorithm understanding, content pillars, hashtag and caption writing, monetisation for creators in India',
      angles: [
        'Reels growth system — hook, retention, CTA, trending audio, posting cadence',
        'Instagram niche and content pillars — picking a niche, 3-pillar strategy, content calendar',
        'Instagram monetisation — brand collabs, UGC, affiliate, digital products, close friends paid',
        'Reels script writing and storytelling — viral formats, hooks, pattern interrupts',
        'Instagram SEO and discoverability — keywords, alt text, captions, hashtags in 2026',
        'Personal brand on Instagram — positioning, bio, highlights, DM funnels',
      ],
      icon: Icons.camera_alt_rounded,
      primary: Color(0xFFF59E0B),
      secondary: Color(0xFFEC4899),
      badge: 'Hot',
    ),
    TrendingCourse(
      id: 't_stock_market',
      title: 'Stock market for beginners',
      tagline: 'Demat, fundamentals, charting & your first safe trade',
      promptHint:
          'Complete beginner-friendly stock market course for Indian investors — Demat account opening, fundamental analysis, technical charting basics, risk management, and long-term investing',
      angles: [
        'Opening a Demat account and first trade — Zerodha, Groww, Upstox walkthrough',
        'Fundamental analysis for Indian stocks — reading annual reports, ratios, screening with Screener.in',
        'Technical analysis basics — candlesticks, support/resistance, moving averages, RSI, MACD',
        'Mutual funds and SIP — direct vs regular, index funds, hybrid funds, tax implications',
        'Risk management and position sizing — stop loss, portfolio allocation, avoiding F&O traps',
        'Long-term investing and compounding — buy-and-hold, rebalancing, Indian blue chips',
      ],
      icon: Icons.trending_up_rounded,
      primary: Color(0xFF14B8A6),
      secondary: Color(0xFF0EA5E9),
      badge: 'Trending',
      defaultLang: 'hi',
    ),
    TrendingCourse(
      id: 't_ielts',
      title: 'Crack IELTS / Spoken English',
      tagline: 'Speaking confidence, writing tricks & band 7+ strategies',
      promptHint:
          'Complete IELTS and spoken English course for Indian students — listening, reading, writing and speaking modules, grammar, confidence building, and band 7+ strategies',
      angles: [
        'IELTS Speaking — fluency, cue card practice, Part 1/2/3 strategies, band 7+ templates',
        'IELTS Writing Task 1 and Task 2 — structure, linkers, model answers, common mistakes',
        'IELTS Listening and Reading — section types, skimming/scanning, timing tricks',
        'Spoken English for daily conversations — sentence patterns, phrasal verbs, pronunciation',
        'English grammar essentials for IELTS — tenses, articles, prepositions, complex sentences',
        'Accent and pronunciation training for Indian speakers — Indian-English patterns to fix, intonation',
      ],
      icon: Icons.record_voice_over_rounded,
      primary: Color(0xFF8B5CF6),
      secondary: Color(0xFF6366F1),
      badge: 'New',
    ),
    TrendingCourse(
      id: 't_ai_tools',
      title: 'Use AI like a pro',
      tagline: 'ChatGPT, Midjourney, Gemini — real workflows that save hours',
      promptHint:
          'Complete AI tools mastery course — how to use ChatGPT, Gemini, Claude, Midjourney, and image/video AI tools for productivity, content, and study workflows',
      angles: [
        'Prompt engineering for ChatGPT and Gemini — frameworks, chaining, system prompts',
        'AI for content creation — ChatGPT + Canva + CapCut pipeline, scripts, thumbnails, reels',
        'AI image generation — Midjourney, DALL·E, Stable Diffusion, prompt styles, commercial use',
        'AI for students — study planning, note summarisation, flashcards, answer writing',
        'AI video tools — Runway, Sora, HeyGen, Descript — making videos without filming',
        'AI productivity stack — Notion AI, Gemini in Gmail/Docs, ChatGPT automations for work',
      ],
      icon: Icons.auto_awesome_rounded,
      primary: Color(0xFFE879F9),
      secondary: Color(0xFF8B5CF6),
      badge: 'Trending',
    ),
  ];
}