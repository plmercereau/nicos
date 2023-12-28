import React from 'react'
import CodeBlock from '@theme/CodeBlock'

export const NixOptions: React.FC<{
    options: Record<
        string,
        {
            description: string
            type: string
            readOnly?: boolean
            default?: {
                _type: string
                text: string
            }
            example?: {
                _type: string
                text: string
            }
            declarations: Array<{ name: string; url: string }>
        }
    >
}> = ({ options }) => {
    return (
        <div>
            {Object.entries(options).map(
                ([
                    name,
                    {
                        description,
                        type,
                        readOnly,
                        default: defaultValue,
                        example,
                        declarations
                    }
                ]) => (
                    <div key={name}>
                        <h2>{name}</h2>
                        <p>{description}</p>
                        <p>
                            Type: {type}
                            {readOnly && <b> (read-only)</b>}
                        </p>
                        {defaultValue && (
                            <p>
                                Default:{' '}
                                <CodeBlock language='nix'>
                                    {defaultValue.text}
                                </CodeBlock>
                            </p>
                        )}
                        {example && (
                            <p>
                                Example:{' '}
                                <CodeBlock language='nix'>
                                    {example.text}
                                </CodeBlock>
                            </p>
                        )}
                        <p>
                            Declared by:
                            <ul>
                                {declarations.map(({ name, url }) => (
                                    <li key={name}>
                                        <a href={url}>{name}</a>
                                    </li>
                                ))}
                            </ul>
                        </p>
                    </div>
                )
            )}
        </div>
    )
}
export default NixOptions
