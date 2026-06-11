"""
Генерация PDF-отчёта ТЗ с помощью reportlab.
"""
import io
from datetime import datetime
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable
)
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.project import Project
from app.models.section import (
    Annotation, BusinessGoal, Requirement, UserStory,
    GlossaryTerm, UseCase, Architecture, DataFlow,
    DataDictionaryEntry, NonFunctionalRequirement,
    Constraint, SystemRequirement, ChangeRecord,
)


SECTION_ORDER = [
    ("Аннотация",                       Annotation,               ["purpose", "info_sources"]),
    ("Бизнес-цели",                     BusinessGoal,             ["title", "content", "metric"]),
    ("Первичный список требований",     Requirement,              ["title", "content", "priority", "status"]),
    ("Пользовательские истории",        UserStory,                ["title", "role", "action", "benefit"]),
    ("Глоссарий",                       GlossaryTerm,             ["term", "definition"]),
    ("Use Cases",                       UseCase,                  ["title", "actor", "main_flow"]),
    ("Архитектура",                     Architecture,             ["title", "content", "diagram_content"]),
    ("Потоки данных",                   DataFlow,                 ["title", "content"]),
    ("Словарь данных",                  DataDictionaryEntry,      ["entity", "attributes"]),
    ("Нефункциональные требования",     NonFunctionalRequirement, ["title", "content", "metric", "value"]),
    ("Ограничения",                     Constraint,               ["title", "content", "impact"]),
    ("Системные требования",            SystemRequirement,        ["title", "specification"]),
    ("Управление изменениями",          ChangeRecord,             ["version", "change_type", "reason"]),
]


def _style():
    styles = getSampleStyleSheet()
    h1 = ParagraphStyle("H1", parent=styles["Heading1"], fontSize=16,
                         spaceAfter=8, textColor=colors.HexColor("#1a237e"))
    h2 = ParagraphStyle("H2", parent=styles["Heading2"], fontSize=13,
                         spaceAfter=6, textColor=colors.HexColor("#283593"))
    body = ParagraphStyle("Body", parent=styles["Normal"], fontSize=10,
                           leading=14, spaceAfter=4)
    return styles, h1, h2, body


def _safe(val):
    if val is None:
        return "—"
    return str(val).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


async def generate_pdf(project_guid: str, db: AsyncSession) -> bytes:
    buf = io.BytesIO()
    doc = SimpleDocTemplate(buf, pagesize=A4,
                             leftMargin=2*cm, rightMargin=2*cm,
                             topMargin=2*cm,  bottomMargin=2*cm)
    styles, h1_style, h2_style, body_style = _style()
    story = []

    # Заголовок проекта
    proj = await db.get(Project, project_guid)
    if proj:
        story.append(Paragraph(f"Техническое задание", styles["Title"]))
        story.append(Paragraph(f"Проект: {_safe(proj.name)}", h1_style))
        story.append(Paragraph(
            f"Статус: {proj.status.value} | Создан: {proj.created_at.strftime('%d.%m.%Y')}",
            body_style,
        ))
        story.append(HRFlowable(width="100%", thickness=1, color=colors.grey))
        story.append(Spacer(1, 0.4*cm))
        if proj.description:
            story.append(Paragraph(_safe(proj.description), body_style))
            story.append(Spacer(1, 0.3*cm))

    # Разделы
    for section_title, model, fields in SECTION_ORDER:
        result = await db.execute(
            select(model).where(model.project_guid == project_guid).order_by(model.order)
        )
        items = result.scalars().all()
        if not items:
            continue

        story.append(Paragraph(section_title, h1_style))
        story.append(HRFlowable(width="100%", thickness=0.5, color=colors.HexColor("#9fa8da")))
        story.append(Spacer(1, 0.2*cm))

        for idx, item in enumerate(items, 1):
            rows = []
            for field in fields:
                val = getattr(item, field, None)
                if val:
                    rows.append([field.replace("_", " ").capitalize(), _safe(val)])
            if rows:
                if hasattr(item, "title") and item.title:
                    story.append(Paragraph(f"{idx}. {_safe(item.title)}", h2_style))
                tbl = Table(rows, colWidths=[4.5*cm, 12*cm])
                tbl.setStyle(TableStyle([
                    ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#e8eaf6")),
                    ("FONTSIZE",   (0, 0), (-1, -1), 9),
                    ("GRID",       (0, 0), (-1, -1), 0.3, colors.HexColor("#c5cae9")),
                    ("VALIGN",     (0, 0), (-1, -1), "TOP"),
                    ("TOPPADDING", (0, 0), (-1, -1), 4),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                ]))
                story.append(tbl)
                story.append(Spacer(1, 0.2*cm))

        story.append(Spacer(1, 0.4*cm))

    # Футер
    story.append(HRFlowable(width="100%", thickness=1, color=colors.grey))
    story.append(Paragraph(
        f"Документ создан: {datetime.utcnow().strftime('%d.%m.%Y %H:%M')} UTC",
        body_style,
    ))

    doc.build(story)
    return buf.getvalue()
