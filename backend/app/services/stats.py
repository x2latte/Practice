"""
Расчёт готовности проекта: взвешенный процент заполненных разделов.
"""
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.models.section import (
    Requirement, Annotation, BusinessGoal, Analog, UserClass,
    UserStory, GlossaryTerm, UseCase, Architecture, DataFlow,
    DataDictionaryEntry, NonFunctionalRequirement, Constraint,
    SystemRequirement, DraftTZ, FinalTZ, ChangeRecord,
)

# (модель, вес, отображаемое имя)
SECTION_WEIGHTS = [
    (Annotation,                "annotation",                   5),
    (BusinessGoal,              "business_goals",               8),
    (Analog,                    "analogs",                      3),
    (Requirement,               "requirements",                10),
    (UserClass,                 "user_classes",                 5),
    (UserStory,                 "user_stories",                 8),
    (GlossaryTerm,              "glossary_terms",               5),
    (UseCase,                   "use_cases",                    8),
    (Architecture,              "architecture",                 8),
    (DataFlow,                  "data_flows",                   6),
    (DataDictionaryEntry,       "data_dictionary",              6),
    (NonFunctionalRequirement,  "non_functional_requirements",  8),
    (Constraint,                "constraints",                  5),
    (SystemRequirement,         "system_requirements",          8),
    (DraftTZ,                   "draft_tz",                     5),
    (FinalTZ,                   "final_tz",                     6),
    (ChangeRecord,              "change_records",               2),
]

TOTAL_WEIGHT = sum(w for _, _, w in SECTION_WEIGHTS)


async def calculate_stats(project_guid: str, db: AsyncSession) -> dict:
    sections_detail: dict[str, int] = {}
    earned_weight = 0

    for model, name, weight in SECTION_WEIGHTS:
        result = await db.execute(
            select(func.count()).where(model.project_guid == project_guid)
        )
        count = result.scalar_one()
        sections_detail[name] = count
        if count > 0:
            earned_weight += weight

    filled   = sum(1 for c in sections_detail.values() if c > 0)
    total    = len(SECTION_WEIGHTS)
    score    = round(earned_weight / TOTAL_WEIGHT * 100, 1)

    return {
        "project_guid":    project_guid,
        "readiness_score": score,
        "filled_sections": filled,
        "total_sections":  total,
        "sections_detail": sections_detail,
    }
