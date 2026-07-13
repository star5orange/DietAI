# Pet Feedback Generator Skill

## Purpose
Generate mood-based feedback text for the virtual pet based on user's diet and water achievement rates.

## Inputs
- diet_progress: diet goal achievement rate (0.0-1.5+)
- water_progress: water goal achievement rate (0.0-1.5+)
- streak_days: consecutive days meeting goals

## Outputs
- mood: happy|normal|hungry|anxious|weak
- feedback: encouraging message text
- streak_encouragement: milestone celebration text (optional)

## Mood Mapping
- happy: diet >= 0.8 AND water >= 0.8
- normal: diet >= 0.6 or water >= 0.6
- hungry: diet == 0 (no food recorded)
- anxious: diet > 1.2 or diet < 0.5
- weak: streak_days == 0 AND diet < 0.6
