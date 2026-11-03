"""Run every query in sql/03_analysis.sql, save the results, and draw charts.

Run:  python run_analysis.py   (after build_database.py)
Writes results/<query_name>.csv and charts/*.png
"""
import re
import sqlite3
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

ROOT = Path(__file__).parent
DB_PATH = ROOT / "data" / "act_ed.db"
RESULTS_DIR = ROOT / "results"
CHARTS_DIR = ROOT / "charts"

# Colours: fixed order, one per location, used the same way in every chart
COLOURS = {"ACT": "#2a78d6", "Canberra Hospital": "#eb6834",
           "North Canberra Hospital": "#1baf7a"}
INK, MUTED, GRID, SURFACE = "#0b0b0b", "#52514e", "#e1e0d9", "#fcfcfb"

plt.rcParams.update({
    "figure.facecolor": SURFACE, "axes.facecolor": SURFACE,
    "axes.edgecolor": "#c3c2b7", "axes.labelcolor": MUTED,
    "xtick.color": MUTED, "ytick.color": MUTED, "text.color": INK,
    "axes.spines.top": False, "axes.spines.right": False,
    "axes.grid": True, "grid.color": GRID, "grid.linewidth": 0.6,
    "font.size": 10, "lines.linewidth": 2, "axes.axisbelow": True,
})


def run_queries(con):
    """Split the .sql file on '-- name:' markers and run each query."""
    sql = (ROOT / "sql" / "03_analysis.sql").read_text()
    results = {}
    for block in re.split(r"^-- name: ", sql, flags=re.M)[1:]:
        name, query = block.split("\n", 1)
        name = name.strip()
        results[name] = pd.read_sql(query, con)
        results[name].to_csv(RESULTS_DIR / f"{name}.csv", index=False)
        print(f"\n=== {name} ===")
        print(results[name].to_string(index=False))
    return results


def save(fig, filename):
    fig.tight_layout()
    fig.savefig(CHARTS_DIR / filename, dpi=150)
    plt.close(fig)


def chart_median_wait(con):
    df = pd.read_sql("""
        SELECT hospital_name, month_start, monthly_value
        FROM v_ed
        WHERE measure = 'median_wait_min' AND triage_name = 'All'
        ORDER BY month_start""", con, parse_dates=["month_start"])
    fig, ax = plt.subplots(figsize=(9, 4.5))
    for name, group in df.groupby("hospital_name"):
        ax.plot(group["month_start"], group["monthly_value"],
                color=COLOURS[name], label=name)
        last = group.iloc[-1]
        ax.annotate(f"{last['monthly_value']:.0f} min", (last["month_start"], last["monthly_value"]),
                    xytext=(6, 0), textcoords="offset points", va="center", color=MUTED)
    ax.set_title("Median wait to start treatment in Canberra EDs (minutes)", loc="left")
    ax.set_ylabel("Minutes")
    ax.set_ylim(bottom=0)
    ax.legend(frameon=False, loc="lower left")
    save(fig, "1_median_wait_trend.png")


def chart_triage_benchmark(results):
    df = results["q3_triage_vs_benchmark"]
    fig, ax = plt.subplots(figsize=(8, 4.5))
    y = range(len(df))
    ax.barh(y, df["actual_pct"], color=COLOURS["ACT"], height=0.6, label="ACT actual")
    ax.scatter(df["benchmark_pct"], y, marker="|", s=500, color=INK,
               linewidths=2.5, zorder=3, label="National benchmark")
    for i, row in df.iterrows():
        ax.annotate(f"{row['actual_pct']:.1f}%  ({row['gap_pct_points']:+.1f} vs target)",
                    (max(row["actual_pct"], row["benchmark_pct"]), i),
                    xytext=(8, 0), textcoords="offset points", va="center", color=MUTED)
    ax.set_yticks(list(y), df["triage_name"])
    ax.invert_yaxis()
    ax.set_xlim(0, 135)
    ax.set_xticks([0, 25, 50, 75, 100])
    ax.set_xlabel("% of patients seen within the recommended time")
    ax.set_title("Patients seen on time vs national benchmark, ACT 2025-26", loc="left")
    ax.grid(axis="y", visible=False)
    ax.legend(frameon=False, loc="upper center", bbox_to_anchor=(0.5, -0.2), ncols=2)
    save(fig, "2_triage_vs_benchmark.png")


def chart_admitted_vs_not(results):
    df = results["q8_admitted_vs_not"]
    df = df[df["hospital_name"] == "ACT"]
    fig, ax = plt.subplots(figsize=(7, 4))
    x = range(len(df))
    width = 0.38
    bars1 = ax.bar([i - width / 2 - 0.01 for i in x], df["not_admitted_pct_4hr"], width,
                   color="#2a78d6", label="Went home (not admitted)")
    bars2 = ax.bar([i + width / 2 + 0.01 for i in x], df["admitted_pct_4hr"], width,
                   color="#eb6834", label="Admitted to a ward")
    ax.bar_label(bars1, fmt="%.0f%%", padding=3, color=MUTED)
    ax.bar_label(bars2, fmt="%.0f%%", padding=3, color=MUTED)
    ax.set_xticks(list(x), df["financial_year"])
    ax.set_ylim(0, 100)
    ax.set_ylabel("% leaving the ED within 4 hours")
    ax.set_title("Admitted patients wait longest in the ED (ACT)", loc="left")
    ax.grid(axis="x", visible=False)
    ax.legend(frameon=False, loc="upper right", ncols=2)
    save(fig, "3_admitted_vs_not_admitted.png")


def main():
    RESULTS_DIR.mkdir(exist_ok=True)
    CHARTS_DIR.mkdir(exist_ok=True)
    con = sqlite3.connect(DB_PATH)
    results = run_queries(con)
    chart_median_wait(con)
    chart_triage_benchmark(results)
    chart_admitted_vs_not(results)
    con.close()
    print(f"\nResults saved to {RESULTS_DIR}\nCharts saved to {CHARTS_DIR}")


if __name__ == "__main__":
    main()
