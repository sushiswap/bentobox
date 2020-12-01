// Concatenate Solidity source code of contracts and their transitive dependencies
// Optimize SPDX tags and move pragmas to top
// ./node_modules/.bin/truffle-flattener SOLIDITY_SOURCE > FLATTENDED_SOLIDITY_SOURCE

const path = require('path');
const fs = require('fs');
const child_process = require('child_process');
const mkdirp = require('mkdirp');

/* flatten: flatten every .sol file in contracts/ */
async function flatten(folder) {
  const dirPath = path.join(__dirname, `../${folder}`);
  return new Promise((resolve, reject) => {
    fs.readdir(dirPath, function(err, dirContents) {
      if (err) {
        console.error(err);
        reject(err);
      }
      let i = 0;
      const promises = [];
      for (i = 0; i < dirContents.length; i++) {
        const n = dirContents[i];
        if (n === 'Migrations.sol' || n === 'ERC20.sol' || !n.endsWith('.sol')) {
          continue;
        }
        const p = path.join(dirPath, n);
        promises.push(flattenFile(p));
      }
      Promise.all(promises).then(resolve, reject);
    });
  });
}

function flattenFile(filePath) {
  mkdirp.sync('flat');
  const pathOut = path.join('flat', path.basename(filePath));
  const fout = fs.createWriteStream(pathOut);
  const p = child_process.spawn('truffle-flattener', [filePath]);
  p.stdout.pipe(fout);
  return new Promise((resolve, reject) => {
    p.on('close', function(code) {
      if (code !== 0) {
        const msg = `truffle-flattener failed with exit status: ${code}`;
        console.log(msg);
        reject(new Error(msg));
      }
      resolve(pathOut);
    });
    p.on('error', function(error) {
      console.error(error);
      reject(error);
    });
  });
}

async function optimize(filePath) {
  const data = fs.readFileSync(filePath, 'UTF-8');
  const lines = data.split("\n");
  let parseMode = false;
  let lastSpdxPos = 0;

  let foundExperimental = false;
  const filtered = []; // array of arrays.
  filtered.push('pragma solidity 0.6.12;');
  filtered.push('');  // space for experimental
  let outPos = 2;
  lines.forEach(line => {
    let skip = false;
    if (line.indexOf('SPDX-License-Identifier') > -1) {
      line = line.replace('SPDX-License-Identifier', 'License-Identifier');
      lastSpdxPos = outPos;
    }
    if (line.indexOf('experimental ABIEncoderV2') > -1) {
      foundExperimental = true;
      skip = true;
    }
    if (line.indexOf('pragma solidity') > -1) {
      skip = true;
    }
    if (!skip) {
      filtered.push(line);
      outPos++;
    }
  });
  if (lastSpdxPos > 0) {
    filtered[lastSpdxPos] = filtered[lastSpdxPos].replace('License-Identifier', 'SPDX-License-Identifier');
  }
  if (foundExperimental) {
    filtered[1] = 'pragma experimental ABIEncoderV2;';
  }
  return new Promise((resolve, reject) => {
    fs.writeFile(filePath, filtered.join("\n"), 'UTF-8', function (err) {
      if (err) {
        console.error(err);
        reject(err);
      }
      resolve();
    });
  });
}


(async function() {
  let files = await flatten('contracts');
  files = files.concat(await flatten('contracts/oracles'));
  files = files.concat(await flatten('contracts/swappers'));
  files.forEach(file => optimize(file));
})();

