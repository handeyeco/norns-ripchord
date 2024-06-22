// transpose ripchord files
const fs = require("node:fs");
const file = "./presets/c-major.rpc"; // EDIT

const noteRegex = /note="(\d+)"/;
const notesRegex = /notes="([0-9;]+)"/;

const notes = ["cs", "d", "ds", "e", "f", "fs", "g", "gs", "a", "as", "b"];

function transpose(letter, number) {
  console.log(number);
  let output = [];

  try {
    const data = fs.readFileSync(file, "utf8");
    data.split("\n").forEach((l) => {
      if (noteRegex.test(l)) {
        const noteMatch = l.match(noteRegex);
        output.push(l.replace(noteMatch[1], parseInt(noteMatch[1]) + number));
      } else if (notesRegex.test(l)) {
        const notesMatch = l.match(notesRegex);
        const notes = notesMatch[1]
          .split(";")
          .map((n) => parseInt(n) + number)
          .join(";");
        output.push(l.replace(notesMatch[1], notes));
      } else {
        output.push(l);
      }
    });
  } catch (err) {
    console.error(err);
  }

  try {
    fs.writeFileSync(`./presets/${letter}-major.rpc`, output.join("\n")); // EDIT
  } catch (err) {
    console.error(err);
  }
}

function main() {
  notes.forEach((v, i) => {
    transpose(v, i + 1);
  });
}

main();
